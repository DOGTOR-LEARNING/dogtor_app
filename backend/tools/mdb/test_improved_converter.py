#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
測試改進的 MDB 轉換器
測試新的 ZIP 解壓縮和 MIME 類型檢測功能
"""

import sys
import os
from pathlib import Path
import zipfile
import io
import magic

# 添加當前目錄到 Python 路徑
sys.path.append(str(Path(__file__).parent))

from mdb_to_csv_converter import MDBToCSVConverter

def create_test_zip():
    """創建一個測試 ZIP 檔案"""
    # 創建測試內容
    test_content = "這是一個測試文字檔案\n包含中文內容\n用於測試 ZIP 解壓縮功能"
    
    # 創建 ZIP 檔案
    zip_buffer = io.BytesIO()
    with zipfile.ZipFile(zip_buffer, 'w', zipfile.ZIP_DEFLATED) as zip_file:
        zip_file.writestr('test.txt', test_content.encode('utf-8'))
        zip_file.writestr('readme.txt', "這是 README 檔案".encode('utf-8'))
    
    return zip_buffer.getvalue()

def test_magic_detection():
    """測試 magic 套件的檔案類型檢測"""
    print("=== 測試 Magic 檔案類型檢測 ===")
    
    # 測試不同類型的資料
    test_data = {
        'ZIP 檔案': create_test_zip(),
        '純文字': "Hello World 中文測試".encode('utf-8'),
        '二進位資料': bytes([0x00, 0x01, 0x02, 0x03, 0xFF]),
    }
    
    for name, data in test_data.items():
        try:
            mime_type = magic.from_buffer(data, mime=True)
            print(f"{name}: {mime_type} ({len(data)} bytes)")
        except Exception as e:
            print(f"❌ {name}: 檢測錯誤 - {e}")

def test_extract_compressed_text():
    """測試解壓縮文字功能"""
    print("\n=== 測試解壓縮文字功能 ===")
    
    # 創建臨時轉換器實例
    converter = MDBToCSVConverter(
        input_dir=".", 
        output_dir="./test_output", 
        max_workers=1
    )
    
    # 測試 ZIP 資料
    zip_data = create_test_zip()
    result = converter._extract_compressed_text(zip_data, "test_001", "test_table")
    print(f"ZIP 解壓縮結果:\n{result}")
    
    # 測試純文字
    text_data = "純文字測試內容 - 中文支援".encode('utf-8')
    result = converter._extract_compressed_text(text_data, "test_002", "test_table")
    print(f"\n純文字結果:\n{result}")
    
    # 測試二進位資料
    binary_data = bytes([0x50, 0x4B] + list(range(100)))  # 假的 ZIP 標頭
    result = converter._extract_compressed_text(binary_data, "test_003", "test_table")
    print(f"\n二進位資料結果:\n{result}")

def test_save_compressed_file():
    """測試保存壓縮檔案功能"""
    print("\n=== 測試保存壓縮檔案功能 ===")
    
    converter = MDBToCSVConverter(
        input_dir=".", 
        output_dir="./test_output", 
        max_workers=1
    )
    
    # 保存 ZIP 檔案
    zip_data = create_test_zip()
    saved_path = converter._save_compressed_file(zip_data, "test_zip", "test_table")
    
    if saved_path:
        print(f"✅ ZIP 檔案已保存至: {saved_path}")
        print(f"檔案大小: {saved_path.stat().st_size} bytes")
        
        # 驗證保存的檔案
        with zipfile.ZipFile(saved_path, 'r') as zip_file:
            print(f"ZIP 檔案內容: {zip_file.namelist()}")
    else:
        print("❌ 保存 ZIP 檔案失敗")

def main():
    """主測試函數"""
    print("開始測試改進的 MDB 轉換器功能...")
    
    try:
        # 檢查依賴
        print("檢查 magic 套件...")
        import magic
        test_buffer = b"test"
        mime_type = magic.from_buffer(test_buffer, mime=True)
        print(f"✅ Magic 套件正常工作，測試結果: {mime_type}")
        
        # 運行測試
        test_magic_detection()
        test_extract_compressed_text()
        test_save_compressed_file()
        
        print("\n✅ 所有測試完成！")
        
    except ImportError as e:
        print(f"❌ 缺少必要套件: {e}")
        print("請執行: pip3 install python-magic")
        sys.exit(1)
    except Exception as e:
        print(f"❌ 測試過程中發生錯誤: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main() 