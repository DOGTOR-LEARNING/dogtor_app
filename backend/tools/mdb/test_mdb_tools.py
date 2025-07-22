#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
MDB Tools 安裝測試腳本
檢查所有必要的依賴是否正確安裝

使用方法：
python test_mdb_tools.py
"""

import sys
import subprocess
import importlib

def test_mdb_tools():
    """測試 mdb-tools 是否安裝"""
    print("🔍 檢查 mdb-tools...")
    try:
        result = subprocess.run(['mdb-ver'], capture_output=True, text=True, check=True)
        print(f"✅ mdb-tools 已安裝: {result.stdout.strip()}")
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        print("❌ mdb-tools 未安裝")
        print("   請執行: brew install mdb-tools")
        return False

def test_python_packages():
    """測試必要的 Python 套件"""
    packages = ['pandas', 'tqdm', 'chardet']
    all_installed = True
    
    print("\n🔍 檢查 Python 套件...")
    
    for package in packages:
        try:
            importlib.import_module(package)
            print(f"✅ {package} 已安裝")
        except ImportError:
            print(f"❌ {package} 未安裝")
            all_installed = False
    
    if not all_installed:
        print("\n請執行安裝命令:")
        print("pip install pandas tqdm chardet")
    
    return all_installed

def test_mdb_commands():
    """測試 mdb-tools 的各個命令"""
    commands = ['mdb-tables', 'mdb-export', 'mdb-schema']
    print("\n🔍 檢查 mdb-tools 命令...")
    
    all_working = True
    for cmd in commands:
        try:
            subprocess.run([cmd, '--help'], capture_output=True, check=True)
            print(f"✅ {cmd} 可用")
        except (subprocess.CalledProcessError, FileNotFoundError):
            print(f"❌ {cmd} 不可用")
            all_working = False
    
    return all_working

def main():
    print("=" * 50)
    print("🧪 MDB to CSV 轉換器 - 環境測試")
    print("=" * 50)
    
    tests_passed = 0
    total_tests = 3
    
    # 測試 mdb-tools
    if test_mdb_tools():
        tests_passed += 1
    
    # 測試 Python 套件
    if test_python_packages():
        tests_passed += 1
    
    # 測試 mdb 命令
    if test_mdb_commands():
        tests_passed += 1
    
    print("\n" + "=" * 50)
    print(f"📊 測試結果: {tests_passed}/{total_tests} 通過")
    
    if tests_passed == total_tests:
        print("🎉 所有測試通過！您可以開始使用 MDB 轉換器了。")
        print("\n📖 使用方法:")
        print("python3 mdb_to_csv_converter.py -i <輸入目錄> -o <輸出目錄>")
    else:
        print("⚠️  請安裝缺少的依賴後重新測試。")
        print("\n📝 完整安裝指令:")
        print("1. brew install mdb-tools")
        print("2. pip install pandas tqdm chardet")
    
    print("=" * 50)

if __name__ == "__main__":
    main() 