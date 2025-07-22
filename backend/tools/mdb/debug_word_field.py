#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
sys.path.append('.')
from mdb_to_csv_converter import MDBToCSVConverter
import tempfile
from pathlib import Path

def test_word_field():
    # 模擬一個典型的亂碼Word欄位資料
    # 這是從實際CSV中提取的一段
    test_data = "IHDRHÞÿÐsRGB®ÎégAMA±üa  pHYsÄÄ+$ÄIDATx^í±GòÇõ?ø?pàð2Å"
    
    print(f"測試資料長度: {len(test_data)} 字元")
    print(f"前50字元: {repr(test_data[:50])}")
    
    with tempfile.TemporaryDirectory() as temp_dir:
        converter = MDBToCSVConverter('.', temp_dir, 1)
        
        # 測試解壓縮
        result = converter._extract_compressed_text(test_data, "test_001", "WordAndPic")
        
        print(f"\n解壓縮結果:")
        print(f"長度: {len(result)} 字元")
        print(f"內容: {result}")
        
        # 檢查保存的檔案
        extracted_dir = Path(temp_dir) / "extracted_files"
        if extracted_dir.exists():
            files = list(extracted_dir.glob("*"))
            print(f"\n保存了 {len(files)} 個檔案:")
            for file in files:
                print(f"  - {file.name} ({file.stat().st_size} bytes)")
                # 檢查檔案內容
                with open(file, 'rb') as f:
                    content = f.read(50)
                    print(f"    前50字節: {content}")
        else:
            print("\n沒有保存檔案")

if __name__ == "__main__":
    test_word_field() 