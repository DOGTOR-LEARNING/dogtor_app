#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
快速測試 Word 欄位的資料轉換
"""

import sys
from pathlib import Path
import tempfile
import os

# 添加當前目錄到 Python 路徑
sys.path.append(str(Path(__file__).parent))

from mdb_to_csv_converter import MDBToCSVConverter

def test_word_field_processing():
    """測試 Word 欄位的處理"""
    print("=== 快速測試 Word 欄位處理 ===")
    
    # 創建臨時轉換器
    with tempfile.TemporaryDirectory() as temp_dir:
        converter = MDBToCSVConverter(
            input_dir=".", 
            output_dir=temp_dir, 
            max_workers=1
        )
        
        # 讀取測試樣本的第2行 (跳過標頭)
        with open('test_sample.csv', 'r', encoding='latin1') as f:
            lines = f.readlines()
            if len(lines) > 1:
                # 解析第2行的 Word 欄位
                line = lines[1].strip()
                # 粗略分割 (假設是CSV格式)
                parts = line.split('","')
                
                if len(parts) >= 4:  # Code,QPic,APic,Word,LessonID
                    word_field = parts[3].strip('"')  # Word 欄位
                    
                    print(f"原始 Word 欄位長度: {len(word_field)} 字元")
                    print(f"前50個字元: {repr(word_field[:50])}")
                    
                    # 測試轉換
                    result = converter._extract_compressed_text(word_field, "test_001", "WordAndPic")
                    
                    print(f"\n轉換結果:")
                    print(f"結果長度: {len(result)} 字元")
                    print(f"內容: {result}")
                    
                    # 檢查是否有檔案被保存
                    extracted_dir = Path(temp_dir) / "extracted_files"
                    if extracted_dir.exists():
                        files = list(extracted_dir.glob("*"))
                        print(f"\n保存的檔案: {len(files)} 個")
                        for file in files:
                            print(f"  - {file.name} ({file.stat().st_size} bytes)")
                    else:
                        print("\n沒有保存檔案")

if __name__ == "__main__":
    test_word_field_processing() 