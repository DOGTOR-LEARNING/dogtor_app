#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MDB to CSV 轉換器
支援批次處理多個 MDB 檔案並轉換為 CSV 格式
適用於 macOS 系統，需要安裝 mdbtools

安裝說明：
1. 安裝 Homebrew (如果還沒安裝)：
   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

2. 安裝 mdbtools 和 libmagic：
   brew install mdbtools libmagic

3. 安裝所需的 Python 套件：
   pip3 install pandas tqdm chardet python-magic

使用方法：
python3 mdb_to_csv_converter.py --input_dir /path/to/mdb/files --output_dir /path/to/csv/output
"""

import os
import sys
import subprocess
import argparse
import csv
import logging
from pathlib import Path
from tqdm import tqdm
import pandas as pd
import chardet
from concurrent.futures import ThreadPoolExecutor, as_completed
import tempfile
import zipfile
import io
import base64
import magic
import json
from datetime import datetime

# 設定日誌
logging.basicConfig(
    level=logging.DEBUG,  # 改為 DEBUG 級別以顯示更多資訊
    format='%(asctime)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler('mdb_conversion.log', encoding='utf-8'),
        logging.StreamHandler(sys.stdout)
    ]
)
logger = logging.getLogger(__name__)

class MDBToCSVConverter:
    def __init__(self, input_dir, output_dir, max_workers=2, chunk_size=10000):
        """
        初始化轉換器
        
        Args:
            input_dir (str): MDB 檔案輸入目錄
            output_dir (str): CSV 檔案輸出目錄
            max_workers (int): 最大併發數
            chunk_size (int): 處理大資料時的分塊大小
        """
        self.input_dir = Path(input_dir)
        self.output_dir = Path(output_dir)
        self.extracted_files_dir = self.output_dir / "extracted_files"  # 存放解壓縮檔案的目錄
        self.max_workers = max_workers
        self.chunk_size = chunk_size
        
        # 確保輸出目錄存在
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.extracted_files_dir.mkdir(parents=True, exist_ok=True)
        
        # 檢查 mdbtools 和 magic 是否已安裝
        self._check_dependencies()
    
    def _check_dependencies(self):
        """檢查必要的依賴套件是否已安裝"""
        # 檢查 mdbtools
        try:
            subprocess.run(['mdb-tables', '--version'], capture_output=True, check=True)
            logger.info("✅ mdbtools 已安裝並可用")
        except (subprocess.CalledProcessError, FileNotFoundError):
            logger.error("❌ mdbtools 未安裝，請執行: brew install mdbtools")
            sys.exit(1)
        
        # 檢查 python-magic
        try:
            import magic
            # 測試 magic 是否正常工作
            magic.from_buffer(b"test", mime=True)
            logger.info("✅ python-magic 已安裝並可用")
        except ImportError:
            logger.error("❌ python-magic 未安裝，請執行: pip3 install python-magic")
            sys.exit(1)
        except Exception as e:
            logger.error(f"❌ python-magic 安裝不完整，請執行: brew install libmagic 然後 pip3 install python-magic")
            logger.error(f"詳細錯誤: {e}")
            sys.exit(1)
    
    def _get_mdb_files(self):
        """取得所有 MDB 檔案"""
        mdb_files = list(self.input_dir.glob("*.mdb")) + list(self.input_dir.glob("*.MDB"))
        if not mdb_files:
            logger.warning(f"在 {self.input_dir} 中找不到 MDB 檔案")
        return mdb_files
    
    def _get_table_list(self, mdb_file):
        """取得 MDB 檔案中的所有表格名稱"""
        try:
            result = subprocess.run(
                ['mdb-tables', str(mdb_file)],
                capture_output=True,
                text=True,
                check=True
            )
            tables = [table.strip() for table in result.stdout.split() if table.strip()]
            return tables
        except subprocess.CalledProcessError as e:
            logger.error(f"無法讀取 {mdb_file} 的表格列表: {e}")
            return []
    
    def _export_table_to_csv(self, mdb_file, table_name, output_file):
        """將單個表格匯出為 CSV"""
        try:
            # 使用 mdb-export 匯出資料
            process = subprocess.Popen(
                ['mdb-export', str(mdb_file), table_name],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=False  # 使用 bytes 模式避免編碼問題
            )
            
            # 取得原始輸出
            stdout_data, stderr_data = process.communicate()
            
            if process.returncode != 0:
                error_msg = stderr_data.decode('utf-8', errors='replace')
                logger.error(f"❌ 匯出 {table_name} 失敗: {error_msg}")
                return False
            
            # 偵測編碼
            detected_encoding = chardet.detect(stdout_data)
            encoding = detected_encoding.get('encoding', 'utf-8')
            confidence = detected_encoding.get('confidence', 0)
            
            logger.info(f"偵測到編碼: {encoding} (信心度: {confidence:.2f})")
            
            # 嘗試不同的編碼方式解碼
            encodings_to_try = [encoding, 'utf-8', 'big5', 'gbk', 'cp1252', 'latin1']
            decoded_data = None
            
            for enc in encodings_to_try:
                if enc is None:
                    continue
                try:
                    decoded_data = stdout_data.decode(enc)
                    logger.info(f"成功使用編碼 {enc} 解碼")
                    break
                except (UnicodeDecodeError, LookupError):
                    continue
            
            if decoded_data is None:
                # 最後手段：使用 errors='replace' 強制解碼
                decoded_data = stdout_data.decode('utf-8', errors='replace')
                logger.warning(f"使用 UTF-8 強制解碼，可能有資料遺失")
            
            # 設定當前表格名稱，供 _simple_process_csv 使用
            self._current_table_name = table_name
            
            # 簡化處理：直接用 UTF-8 重新解碼並過濾欄位
            processed_data = self._simple_process_csv(decoded_data)
            
            # 寫入處理後的 CSV 檔案
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                f.write(processed_data)
            
            # 計算行數
            line_count = processed_data.count('\n')
            
            logger.info(f"✅ 成功匯出 {table_name} -> {output_file.name} ({line_count} 行)")
            return True
                    
        except Exception as e:
            logger.error(f"❌ 匯出 {table_name} 時發生錯誤: {e}")
            return False
    
    def _process_large_csv(self, csv_file):
        """處理大型 CSV 檔案，進行優化"""
        try:
            file_size = os.path.getsize(csv_file)
            
            # 如果檔案小於 100MB，直接返回
            if file_size < 100 * 1024 * 1024:
                return
            
            logger.info(f"處理大型檔案 {csv_file.name} ({file_size / 1024 / 1024:.1f} MB)")
            
            # 檢測編碼
            with open(csv_file, 'rb') as f:
                raw_data = f.read(10000)
                encoding = chardet.detect(raw_data)['encoding']
            
            # 分塊處理大檔案
            temp_file = csv_file.with_suffix('.tmp')
            
            try:
                chunk_iter = pd.read_csv(csv_file, encoding=encoding, chunksize=self.chunk_size)
                
                first_chunk = True
                for chunk in chunk_iter:
                    # 清理資料
                    chunk = chunk.dropna(how='all')  # 移除完全空白的行
                    chunk = chunk.fillna('')  # 填充 NaN 值
                    
                    # 寫入臨時檔案
                    chunk.to_csv(
                        temp_file, 
                        mode='a' if not first_chunk else 'w',
                        header=first_chunk,
                        index=False,
                        encoding='utf-8'
                    )
                    first_chunk = False
                
                # 替換原檔案
                temp_file.replace(csv_file)
                logger.info(f"✅ 大型檔案處理完成: {csv_file.name}")
                
            except Exception as chunk_error:
                logger.warning(f"⚠️ 無法分塊處理檔案 {csv_file.name}: {chunk_error}")
                # 如果分塊處理失敗，保留原檔案
                if temp_file.exists():
                    temp_file.unlink()
            
        except Exception as e:
            logger.error(f"❌ 處理大型檔案 {csv_file.name} 時發生錯誤: {e}")
    
    def _save_compressed_file(self, compressed_data, record_id, table_name):
        """保存壓縮檔案到磁碟"""
        try:
            if not compressed_data:
                return None
            
            # 使用 magic 判斷檔案類型
            mime_type = magic.from_buffer(compressed_data, mime=True)
            logger.debug(f"偵測到 MIME type: {mime_type}")
            
            # 根據 MIME type 和檔案內容確定副檔名
            extension_map = {
                'application/zip': '.zip',
                'application/x-zip-compressed': '.zip',
                'application/octet-stream': '.bin',
                'text/plain': '.txt',
                'application/pdf': '.pdf',
                'application/msword': '.doc',
                'application/vnd.openxmlformats-officedocument.wordprocessingml.document': '.docx',
                'image/jpeg': '.jpg',
                'image/png': '.png',
            }
            
            # 檢查檔案標頭來覆蓋MIME檢測結果
            if compressed_data[:2] == b'PK':
                extension = '.zip'
            elif (compressed_data[:8] == b'\x89PNG\r\n\x1a\n' or 
                  b'PNG' in compressed_data[:20] or 
                  b'IHDR' in compressed_data[:20]):
                extension = '.png'
            elif compressed_data[:2] == b'\xff\xd8':
                extension = '.jpg'
            else:
                extension = extension_map.get(mime_type, '.bin')
            
            # 建立檔案路徑
            safe_table_name = table_name.replace('/', '_').replace('\\', '_')
            filename = f"{safe_table_name}_{record_id}{extension}"
            file_path = self.extracted_files_dir / filename
            
            # 保存檔案
            with open(file_path, 'wb') as f:
                f.write(compressed_data)
            
            logger.info(f"已保存壓縮檔案: {filename} (MIME: {mime_type}, 大小: {len(compressed_data)} bytes)")
            return file_path
            
        except Exception as e:
            logger.error(f"保存壓縮檔案時發生錯誤: {e}")
            return None
    
    def _extract_compressed_text(self, compressed_data, record_id=None, table_name=None):
        """解壓縮 Word 欄位中的文字內容並保存原始檔案"""
        try:
            if not compressed_data or len(compressed_data) < 2:
                return ""
            
            # 將字串轉換為 bytes (如果需要)
            if isinstance(compressed_data, str):
                # 嘗試不同方法將字串轉為原始二進位資料
                binary_data = None
                
                # 方法 1: 嘗試 latin1 編碼 (保留原始位元組)
                try:
                    binary_data = compressed_data.encode('latin1')
                    logger.debug(f"使用 latin1 編碼轉換，資料大小: {len(binary_data)} bytes")
                except UnicodeEncodeError:
                    pass
                
                # 方法 2: 如果包含無法用 latin1 編碼的字符，嘗試 base64 解碼
                if binary_data is None:
                    try:
                        # 移除可能的空白字符
                        clean_data = ''.join(compressed_data.split())
                        binary_data = base64.b64decode(clean_data)
                        logger.debug(f"使用 base64 解碼，資料大小: {len(binary_data)} bytes")
                    except:
                        pass
                
                # 方法 3: 嘗試 hex 解碼
                if binary_data is None:
                    try:
                        # 假設資料是十六進位字串
                        clean_hex = ''.join(c for c in compressed_data if c in '0123456789abcdefABCDEF')
                        if len(clean_hex) % 2 == 0 and len(clean_hex) > 0:
                            binary_data = bytes.fromhex(clean_hex)
                            logger.debug(f"使用 hex 解碼，資料大小: {len(binary_data)} bytes")
                    except:
                        pass
                
                # 方法 4: 最後手段，使用 UTF-8 並忽略錯誤
                if binary_data is None:
                    binary_data = compressed_data.encode('utf-8', errors='ignore')
                    logger.debug(f"使用 UTF-8 強制編碼，資料大小: {len(binary_data)} bytes")
                    
            else:
                binary_data = compressed_data
                logger.debug(f"輸入已經是二進位資料，大小: {len(binary_data)} bytes")
            
            # 使用 magic 判斷檔案類型
            mime_type = magic.from_buffer(binary_data, mime=True)
            logger.debug(f"偵測到 MIME type: {mime_type}")
            
            # 保存原始檔案
            if record_id and table_name:
                saved_path = self._save_compressed_file(binary_data, record_id, table_name)
                if saved_path:
                    logger.debug(f"原始檔案已保存至: {saved_path}")
            
            extracted_text = ""
            
            # 根據 MIME type 和檔案標頭處理不同類型的檔案
            
            # 檢查是否為 ZIP 檔案
            is_zip = (mime_type in ['application/zip', 'application/x-zip-compressed'] or 
                     binary_data[:2] == b'PK' or  # ZIP 魔術數字
                     binary_data[:4] == b'PK\x03\x04')  # ZIP 本地檔案標頭
            
            # 檢查是否為 PNG 檔案（完整或片段）
            is_png = (mime_type == 'image/png' or 
                     binary_data[:8] == b'\x89PNG\r\n\x1a\n' or  # 完整PNG標頭
                     b'PNG' in binary_data[:20] or  # PNG標識
                     b'IHDR' in binary_data[:20])  # PNG圖片標頭塊
            
            # 檢查是否為 JPEG 檔案
            is_jpeg = (mime_type in ['image/jpeg', 'image/jpg'] or
                      binary_data[:2] == b'\xff\xd8')  # JPEG標頭
            
            if is_zip:
                try:
                    with zipfile.ZipFile(io.BytesIO(binary_data)) as zip_file:
                        logger.info(f"ZIP 檔案包含以下檔案: {zip_file.namelist()}")
                        
                        # 嘗試解壓縮所有文字檔案
                        text_parts = []
                        
                        for file_name in zip_file.namelist():
                            try:
                                file_content = zip_file.read(file_name)
                                file_mime = magic.from_buffer(file_content, mime=True)
                                
                                logger.debug(f"ZIP 內檔案 {file_name} 的 MIME type: {file_mime}")
                                
                                # 如果是文字檔案，嘗試解碼
                                if file_mime.startswith('text/'):
                                    for encoding in ['utf-8', 'big5', 'gbk', 'cp1252', 'latin1']:
                                        try:
                                            text = file_content.decode(encoding).strip()
                                            if text:
                                                text_parts.append(f"[{file_name}]: {text}")
                                                break
                                        except UnicodeDecodeError:
                                            continue
                                else:
                                    # 非文字檔案，記錄檔案資訊
                                    text_parts.append(f"[{file_name}]: 非文字檔案 ({file_mime}, {len(file_content)} bytes)")
                                    
                            except Exception as e:
                                logger.warning(f"無法讀取 ZIP 內檔案 {file_name}: {e}")
                                text_parts.append(f"[{file_name}]: 讀取錯誤")
                        
                        extracted_text = "\n".join(text_parts)
                        
                except zipfile.BadZipFile as e:
                    logger.warning(f"ZIP 檔案格式錯誤: {e}")
                    extracted_text = f"[ZIP 格式錯誤: {e}]"
                except Exception as e:
                    logger.warning(f"處理 ZIP 檔案時發生錯誤: {e}")
                    extracted_text = f"[ZIP 處理錯誤: {e}]"
            
            elif is_png:
                try:
                    # PNG 圖片檔案
                    extracted_text = f"[PNG圖片: {len(binary_data)} bytes"
                    
                    # 嘗試從PNG中提取基本資訊
                    if b'IHDR' in binary_data:
                        ihdr_pos = binary_data.find(b'IHDR')
                        if ihdr_pos >= 0 and len(binary_data) > ihdr_pos + 12:
                                                         # PNG IHDR 結構：長度(4) + "IHDR"(4) + 寬度(4) + 高度(4)
                             width_bytes = binary_data[ihdr_pos+4:ihdr_pos+8]
                             height_bytes = binary_data[ihdr_pos+8:ihdr_pos+12]
                             if len(width_bytes) == 4 and len(height_bytes) == 4:
                                 try:
                                     import struct
                                     width = struct.unpack('>I', width_bytes)[0]
                                     height = struct.unpack('>I', height_bytes)[0]
                                     # 驗證像素值是否合理（避免錯誤解析）
                                     if width > 0 and height > 0 and width < 100000 and height < 100000:
                                         extracted_text += f", {width}x{height}像素"
                                     else:
                                         extracted_text += ", 像素資訊不完整"
                                 except:
                                     extracted_text += ", 像素解析失敗"
                    
                    extracted_text += "]"
                    
                except Exception as e:
                    logger.warning(f"處理PNG檔案時發生錯誤: {e}")
                    extracted_text = f"[PNG檔案處理錯誤: {len(binary_data)} bytes]"
            
            elif is_jpeg:
                # JPEG 圖片檔案
                extracted_text = f"[JPEG圖片: {len(binary_data)} bytes]"
            
            elif mime_type.startswith('text/'):
                # 純文字檔案
                for encoding in ['utf-8', 'big5', 'gbk', 'cp1252', 'latin1']:
                    try:
                        extracted_text = binary_data.decode(encoding).strip()
                        if extracted_text:
                            break
                    except UnicodeDecodeError:
                        continue
            
            else:
                # 其他類型的檔案
                extracted_text = f"[二進位檔案: {mime_type}, {len(binary_data)} bytes]"
            
            # 如果沒有提取到文字，嘗試強制解碼
            if not extracted_text:
                extracted_text = binary_data.decode('utf-8', errors='replace').strip()
                if not extracted_text or len(extracted_text.strip()) < 3:
                    extracted_text = f"[無法解碼: {mime_type}, {len(binary_data)} bytes]"
            
            return extracted_text
            
        except Exception as e:
            logger.error(f"解壓縮文字內容時發生錯誤: {e}")
            return f"[解析錯誤: {e}]"
    
    def _simple_process_csv(self, raw_data):
        """簡化的 CSV 處理：只保留文字欄位，強制 UTF-8 解碼"""
        try:
            lines = raw_data.split('\n')
            if not lines:
                return ""
            
            # 處理標頭
            header_line = lines[0]
            headers = [h.strip().strip('"') for h in header_line.split(',')]
            logger.info(f"原始欄位: {headers}")
            
            # 找到要保留的欄位（跳過圖片欄位）
            keep_headers = []
            keep_indices = []
            
            for i, header in enumerate(headers):
                if header.lower() not in ['qpic', 'apic']:
                    keep_headers.append(header)
                    keep_indices.append(i)
            
            logger.info(f"保留欄位: {keep_headers}")
            
            # 建立輸出
            output_lines = [','.join(f'"{h}"' for h in keep_headers)]
            
            # 處理資料行 - 使用簡單的方法
            processed_count = 0
            for line_num, line in enumerate(lines[1:], 1):
                if not line.strip():
                    continue
                
                try:
                    # 簡單分割（可能不完美，但避免二進位問題）
                    parts = line.split('","')
                    
                    # 清理引號
                    if parts:
                        parts[0] = parts[0].lstrip('"')
                        parts[-1] = parts[-1].rstrip('"')
                    
                    # 只保留需要的欄位
                    row_data = []
                    for idx in keep_indices:
                        if idx < len(parts):
                            value = parts[idx]
                            
                            # 對 Word 欄位進行特殊處理
                            if idx < len(headers) and headers[idx].lower() == 'word':
                                # 使用新的解壓縮方法處理 Word 欄位
                                try:
                                    # 為每個記錄生成唯一 ID (使用行號)
                                    record_id = f"row_{line_num}"
                                    # 使用當前檔案名作為 table_name
                                    table_name = getattr(self, '_current_table_name', 'unknown')
                                    
                                    # 檢查是否有實際內容（改為更寬鬆的條件）
                                    if value and len(value.strip()) > 5:
                                        # 嘗試解壓縮內容
                                        extracted_text = self._extract_compressed_text(value, record_id, table_name)
                                        value = extracted_text if extracted_text else "[無內容]"
                                        logger.debug(f"處理了 Word 欄位 (行 {line_num}): {len(value)} 字元")
                                    else:
                                        value = ""
                                        logger.debug(f"跳過 Word 欄位 (行 {line_num}): 內容太短 ({len(value) if value else 0} 字元)")
                                except Exception as e:
                                    logger.warning(f"處理 Word 欄位時發生錯誤 (行 {line_num}): {e}")
                                    value = f"[處理錯誤: {e}]"
                            else:
                                # 一般欄位也做清理
                                try:
                                    value = value.encode('utf-8', errors='ignore').decode('utf-8', errors='ignore')
                                    value = ''.join(char for char in value if char.isprintable() or char.isspace())
                                except:
                                    value = ""
                            
                            # 轉義引號並加入
                            value = str(value).replace('"', '""')
                            row_data.append(f'"{value}"')
                        else:
                            row_data.append('""')
                    
                    if row_data:
                        output_lines.append(','.join(row_data))
                        processed_count += 1
                    
                    # 顯示進度
                    if line_num % 50000 == 0:
                        logger.info(f"已處理 {line_num} 行，有效資料 {processed_count} 行")
                
                except Exception as e:
                    logger.debug(f"跳過第 {line_num} 行: {e}")
                    continue
            
            result = '\n'.join(output_lines)
            logger.info(f"簡化處理完成，輸出 {len(output_lines)} 行 (有效資料 {processed_count} 行)")
            return result
            
        except Exception as e:
            logger.error(f"簡化處理失敗: {e}")
            # 最後手段：只返回標頭
            try:
                headers = [h.strip().strip('"') for h in raw_data.split('\n')[0].split(',')]
                clean_headers = [h for h in headers if h.lower() not in ['qpic', 'apic']]
                return ','.join(f'"{h}"' for h in clean_headers)
            except:
                return "Code,Word,LessonID"
    
    def _process_csv_data(self, raw_data):
        """處理 CSV 資料，跳過圖片欄位並解壓縮文字"""
        try:
            # 找到標頭行
            lines = raw_data.split('\n', 1)  # 只分割第一行
            if len(lines) < 2:
                return ""
            
            header_line = lines[0]
            data_content = lines[1]
            
            # 解析標頭 - 標頭應該是乾淨的
            headers = [h.strip('"') for h in header_line.split(',')]
            logger.info(f"找到欄位: {headers}")
            
            # 找到需要保留的欄位索引
            keep_indices = []
            keep_headers = []
            
            for i, header in enumerate(headers):
                header_lower = header.lower().strip()
                if header_lower not in ['qpic', 'apic']:  # 跳過圖片欄位
                    keep_indices.append(i)
                    keep_headers.append(header)
            
            logger.info(f"保留欄位: {keep_headers}")
            
            # 建立輸出標頭
            output_lines = [','.join(f'"{h}"' for h in keep_headers)]
            
            # 使用更精確的方法解析每一行
            # 手動解析 CSV，因為包含二進位資料
            line_num = 0
            pos = 0
            
            while pos < len(data_content):
                line_num += 1
                
                # 尋找下一行的開始
                if data_content[pos] != '"':
                    # 尋找下一個引號開始
                    next_quote = data_content.find('"', pos)
                    if next_quote == -1:
                        break
                    pos = next_quote
                
                # 解析當前行的所有欄位
                row_values = []
                field_index = 0
                
                while field_index < len(headers) and pos < len(data_content):
                    if data_content[pos] == '"':
                        # 找到欄位內容的結束
                        pos += 1  # 跳過開始的引號
                        field_start = pos
                        
                        # 尋找欄位結束的引號
                        quote_count = 0
                        while pos < len(data_content):
                            if data_content[pos] == '"':
                                # 檢查是否為轉義的引號
                                if pos + 1 < len(data_content) and data_content[pos + 1] == '"':
                                    pos += 2  # 跳過轉義的引號
                                    continue
                                else:
                                    # 找到欄位結束
                                    field_value = data_content[field_start:pos]
                                    row_values.append(field_value)
                                    pos += 1  # 跳過結束引號
                                    break
                            else:
                                pos += 1
                        
                        # 跳過逗號或換行
                        if pos < len(data_content) and data_content[pos] == ',':
                            pos += 1
                        elif pos < len(data_content) and data_content[pos] in '\r\n':
                            # 跳過換行符號
                            if data_content[pos] == '\r' and pos + 1 < len(data_content) and data_content[pos + 1] == '\n':
                                pos += 2
                            else:
                                pos += 1
                            break
                    else:
                        # 處理沒有引號的欄位（不太可能在這個資料集中）
                        field_start = pos
                        while pos < len(data_content) and data_content[pos] not in ',\r\n':
                            pos += 1
                        field_value = data_content[field_start:pos]
                        row_values.append(field_value)
                        
                        if pos < len(data_content) and data_content[pos] == ',':
                            pos += 1
                        elif pos < len(data_content) and data_content[pos] in '\r\n':
                            if data_content[pos] == '\r' and pos + 1 < len(data_content) and data_content[pos + 1] == '\n':
                                pos += 2
                            else:
                                pos += 1
                            break
                    
                    field_index += 1
                
                # 處理這一行的資料
                if row_values:
                    processed_row = []
                    for i in keep_indices:
                        if i < len(row_values):
                            value = row_values[i]
                            
                            # 如果是 Word 欄位，嘗試解壓縮
                            if headers[i].lower().strip() == 'word' and value:
                                try:
                                    # 檢查是否為 ZIP 格式
                                    if len(value) > 2:
                                        binary_data = value.encode('latin1', errors='ignore')
                                        if binary_data[:2] == b'PK':
                                            extracted_text = self._extract_compressed_text(binary_data)
                                            if extracted_text:
                                                value = extracted_text
                                            else:
                                                value = f"[壓縮文字_{line_num}]"
                                except Exception as e:
                                    logger.warning(f"解壓縮第 {line_num} 行文字時發生錯誤: {e}")
                                    value = f"[解析錯誤_{line_num}]"
                            
                            # 清理值並轉義
                            value = str(value).replace('"', '""')
                            processed_row.append(f'"{value}"')
                        else:
                            processed_row.append('""')
                    
                    if processed_row:
                        output_lines.append(','.join(processed_row))
                
                # 顯示進度
                if line_num % 10000 == 0:
                    logger.info(f"已處理 {line_num} 行...")
            
            result = '\n'.join(output_lines)
            logger.info(f"處理完成，輸出 {len(output_lines)} 行")
            return result
            
        except Exception as e:
            logger.error(f"處理 CSV 資料時發生錯誤: {e}")
            # 返回僅包含標頭的簡化版本
            try:
                lines = raw_data.split('\n')
                if lines:
                    headers = [h.strip('"') for h in lines[0].split(',')]
                    keep_headers = [h for h in headers if h.lower() not in ['qpic', 'apic']]
                    return ','.join(f'"{h}"' for h in keep_headers)
            except:
                pass
            return raw_data
    
    def convert_single_mdb(self, mdb_file):
        """轉換單個 MDB 檔案"""
        logger.info(f"開始處理 MDB 檔案: {mdb_file.name}")
        
        # 取得表格列表
        tables = self._get_table_list(mdb_file)
        if not tables:
            logger.warning(f"在 {mdb_file.name} 中找不到表格")
            return False
        
        logger.info(f"找到 {len(tables)} 個表格: {tables}")
        
        # 為每個 MDB 檔案建立對應的輸出目錄
        mdb_output_dir = self.output_dir / mdb_file.stem
        mdb_output_dir.mkdir(exist_ok=True)
        
        success_count = 0
        
        # 處理每個表格
        for table in tqdm(tables, desc=f"處理 {mdb_file.name}"):
            output_file = mdb_output_dir / f"{table}.csv"
            
            if self._export_table_to_csv(mdb_file, table, output_file):
                # 處理大型 CSV 檔案
                self._process_large_csv(output_file)
                success_count += 1
        
        logger.info(f"完成處理 {mdb_file.name}: {success_count}/{len(tables)} 個表格成功轉換")
        return success_count == len(tables)
    
    def convert_all_mdb_files(self):
        """批次轉換所有 MDB 檔案"""
        mdb_files = self._get_mdb_files()
        
        if not mdb_files:
            logger.error("沒有找到要處理的 MDB 檔案")
            return
        
        logger.info(f"找到 {len(mdb_files)} 個 MDB 檔案")
        
        # 使用執行緒池進行併發處理
        with ThreadPoolExecutor(max_workers=self.max_workers) as executor:
            future_to_file = {
                executor.submit(self.convert_single_mdb, mdb_file): mdb_file 
                for mdb_file in mdb_files
            }
            
            successful_conversions = 0
            
            for future in as_completed(future_to_file):
                mdb_file = future_to_file[future]
                try:
                    success = future.result()
                    if success:
                        successful_conversions += 1
                except Exception as e:
                    logger.error(f"處理 {mdb_file.name} 時發生錯誤: {e}")
        
        logger.info(f"轉換完成！成功處理 {successful_conversions}/{len(mdb_files)} 個檔案")
    
    def get_conversion_summary(self):
        """取得轉換摘要資訊"""
        summary = {
            'total_csv_files': 0,
            'total_size_mb': 0,
            'directories': [],
            'extracted_files': {
                'count': 0,
                'size_mb': 0,
                'types': {}
            }
        }
        
        for item in self.output_dir.iterdir():
            if item.is_dir() and item.name != 'extracted_files':
                csv_files = list(item.glob("*.csv"))
                dir_size = sum(f.stat().st_size for f in csv_files)
                
                summary['directories'].append({
                    'name': item.name,
                    'csv_count': len(csv_files),
                    'size_mb': dir_size / 1024 / 1024
                })
                
                summary['total_csv_files'] += len(csv_files)
                summary['total_size_mb'] += dir_size / 1024 / 1024
        
        # 統計解壓縮檔案
        if self.extracted_files_dir.exists():
            extracted_files = list(self.extracted_files_dir.glob("*"))
            summary['extracted_files']['count'] = len(extracted_files)
            
            total_extracted_size = 0
            for file_path in extracted_files:
                if file_path.is_file():
                    file_size = file_path.stat().st_size
                    total_extracted_size += file_size
                    
                    # 統計檔案類型
                    extension = file_path.suffix.lower()
                    if extension in summary['extracted_files']['types']:
                        summary['extracted_files']['types'][extension] += 1
                    else:
                        summary['extracted_files']['types'][extension] = 1
            
            summary['extracted_files']['size_mb'] = total_extracted_size / 1024 / 1024
        
        return summary

def main():
    parser = argparse.ArgumentParser(description='MDB to CSV 批次轉換器')
    parser.add_argument('--input_dir', '-i', required=True, help='MDB 檔案輸入目錄')
    parser.add_argument('--output_dir', '-o', required=True, help='CSV 檔案輸出目錄')
    parser.add_argument('--max_workers', '-w', type=int, default=4, help='最大併發數 (預設: 4)')
    parser.add_argument('--chunk_size', '-c', type=int, default=10000, help='大檔案處理分塊大小 (預設: 10000)')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.input_dir):
        logger.error(f"輸入目錄不存在: {args.input_dir}")
        sys.exit(1)
    
    # 建立轉換器並執行轉換
    converter = MDBToCSVConverter(
        args.input_dir, 
        args.output_dir, 
        args.max_workers, 
        args.chunk_size
    )
    
    # 執行轉換
    converter.convert_all_mdb_files()
    
    # 顯示摘要
    summary = converter.get_conversion_summary()
    logger.info("\n=== 轉換摘要 ===")
    logger.info(f"總共產生 {summary['total_csv_files']} 個 CSV 檔案")
    logger.info(f"總大小: {summary['total_size_mb']:.1f} MB")
    
    for dir_info in summary['directories']:
        logger.info(f"  📁 {dir_info['name']}: {dir_info['csv_count']} 個檔案, {dir_info['size_mb']:.1f} MB")
    
    # 顯示解壓縮檔案摘要
    extracted = summary['extracted_files']
    if extracted['count'] > 0:
        logger.info(f"\n=== 解壓縮檔案摘要 ===")
        logger.info(f"總共解壓縮 {extracted['count']} 個檔案")
        logger.info(f"解壓縮檔案總大小: {extracted['size_mb']:.1f} MB")
        logger.info("檔案類型分佈:")
        for ext, count in extracted['types'].items():
            logger.info(f"  {ext if ext else '無副檔名'}: {count} 個檔案")

if __name__ == "__main__":
    main() 