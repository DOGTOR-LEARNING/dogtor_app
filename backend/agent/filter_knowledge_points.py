import pandas as pd
import os
from collections import Counter
import argparse

def analyze_and_filter_knowledge_points(input_file: str, min_questions: int = 3, output_file: str = None, backup: bool = True):
    """
    分析並過濾掉參考題目數量少於指定數量的知識點
    
    Args:
        input_file: 輸入的CSV檔案路徑
        min_questions: 知識點最少需要的題目數量（預設為3）
        output_file: 輸出檔案路徑（預設為輸入檔案加上_filtered後綴）
        backup: 是否備份原始檔案（預設為True）
    """
    
    # 檢查檔案是否存在
    if not os.path.exists(input_file):
        print(f"錯誤：找不到檔案 {input_file}")
        return False
    
    print(f"載入檔案: {input_file}")
    
    try:
        # 讀取CSV檔案
        df = pd.read_csv(input_file, encoding='utf-8-sig')
        print(f"總共載入 {len(df)} 筆記錄")
        
        # 顯示狀態統計
        status_counts = df['status'].value_counts()
        print(f"\n狀態統計:")
        for status, count in status_counts.items():
            print(f"  {status}: {count} 筆")
        
        # 過濾出成功匹配的記錄
        matched_df = df[df['status'] == 'matched'].copy()
        print(f"\n成功匹配的記錄: {len(matched_df)} 筆")
        
        if len(matched_df) == 0:
            print("警告：沒有找到任何成功匹配的記錄")
            return False
        
        # 統計每個知識點的題目數量
        knowledge_point_counts = Counter(matched_df['matched_knowledge_point'].tolist())
        print(f"\n發現 {len(knowledge_point_counts)} 個不同的知識點")
        
        # 找出題目數量少於指定數量的知識點
        insufficient_kps = [kp for kp, count in knowledge_point_counts.items() if count < min_questions]
        sufficient_kps = [kp for kp, count in knowledge_point_counts.items() if count >= min_questions]
        
        print(f"\n知識點分析結果:")
        print(f"  題目數量 >= {min_questions} 的知識點: {len(sufficient_kps)} 個")
        print(f"  題目數量 < {min_questions} 的知識點: {len(insufficient_kps)} 個")
        
        # 顯示每個知識點的題目數量分佈
        print(f"\n題目數量分佈:")
        count_distribution = Counter(knowledge_point_counts.values())
        for count, num_kps in sorted(count_distribution.items()):
            print(f"  {count} 題: {num_kps} 個知識點")
        
        # 顯示題目數量不足的知識點詳細資訊
        if insufficient_kps:
            print(f"\n題目數量不足的知識點詳細資訊:")
            for kp in sorted(insufficient_kps):
                count = knowledge_point_counts[kp]
                print(f"  - {kp}: {count} 題")
        
        # 計算需要移除的記錄數量
        records_to_remove = len(matched_df[matched_df['matched_knowledge_point'].isin(insufficient_kps)])
        records_to_keep_matched = len(matched_df[matched_df['matched_knowledge_point'].isin(sufficient_kps)])
        
        print(f"\n處理統計:")
        print(f"  原始總記錄數: {len(df)}")
        print(f"  成功匹配的記錄: {len(matched_df)}")
        print(f"  題目不足需移除的匹配記錄: {records_to_remove}")
        print(f"  保留的匹配記錄: {records_to_keep_matched}")
        
        # 過濾資料：移除題目數量不足的知識點記錄
        # 保留非matched狀態的記錄 + 題目數量足夠的matched記錄
        filtered_df = pd.concat([
            df[df['status'] != 'matched'],  # 保留所有非matched記錄
            matched_df[matched_df['matched_knowledge_point'].isin(sufficient_kps)]  # 只保留題目足夠的matched記錄
        ], ignore_index=True)
        
        print(f"  過濾後總記錄數: {len(filtered_df)}")
        
        # 決定輸出檔案名稱
        if output_file is None:
            base_name, ext = os.path.splitext(input_file)
            output_file = f"{base_name}_filtered{ext}"
        
        # 備份原始檔案
        if backup:
            backup_file = f"{input_file}.backup"
            if not os.path.exists(backup_file):
                df.to_csv(backup_file, index=False, encoding='utf-8-sig')
                print(f"\n已備份原始檔案到: {backup_file}")
            else:
                print(f"\n備份檔案已存在: {backup_file}")
        
        # 儲存過濾後的檔案
        filtered_df.to_csv(output_file, index=False, encoding='utf-8-sig')
        print(f"已儲存過濾後的檔案到: {output_file}")
        
        # 生成報告
        report_file = f"{os.path.splitext(output_file)[0]}_report.txt"
        generate_report(insufficient_kps, knowledge_point_counts, report_file, min_questions)
        
        return True
        
    except Exception as e:
        print(f"處理過程中發生錯誤: {e}")
        import traceback
        traceback.print_exc()
        return False

def generate_report(insufficient_kps, knowledge_point_counts, report_file, min_questions):
    """生成詳細報告"""
    try:
        with open(report_file, 'w', encoding='utf-8') as f:
            f.write("知識點過濾報告\n")
            f.write("=" * 50 + "\n\n")
            
            f.write(f"過濾條件: 移除題目數量少於 {min_questions} 題的知識點\n\n")
            
            f.write(f"移除的知識點清單 (共 {len(insufficient_kps)} 個):\n")
            f.write("-" * 30 + "\n")
            
            for kp in sorted(insufficient_kps):
                count = knowledge_point_counts[kp]
                f.write(f"- {kp}: {count} 題\n")
            
            f.write(f"\n總計移除 {len(insufficient_kps)} 個知識點\n")
            
            # 統計每個題目數量有多少知識點
            count_distribution = Counter(knowledge_point_counts.values())
            f.write(f"\n原始知識點題目數量分佈:\n")
            f.write("-" * 30 + "\n")
            for count, num_kps in sorted(count_distribution.items()):
                status = "✓ 保留" if count >= min_questions else "✗ 移除"
                f.write(f"{count} 題: {num_kps} 個知識點 ({status})\n")
        
        print(f"已生成詳細報告: {report_file}")
        
    except Exception as e:
        print(f"生成報告時發生錯誤: {e}")

def main():
    parser = argparse.ArgumentParser(description='過濾知識點參考題目數量不足的記錄')
    parser.add_argument('input_file', help='輸入的CSV檔案路徑', default='processing/question_knowledge_point_matching_results.csv', nargs='?')
    parser.add_argument('--min-questions', type=int, default=3, help='知識點最少需要的題目數量 (預設: 3)')
    parser.add_argument('--output', help='輸出檔案路徑 (預設: 輸入檔案名_filtered.csv)')
    parser.add_argument('--no-backup', action='store_true', help='不備份原始檔案')
    
    args = parser.parse_args()
    
    print("知識點參考題目過濾工具")
    print("=" * 40)
    
    success = analyze_and_filter_knowledge_points(
        input_file=args.input_file,
        min_questions=args.min_questions,
        output_file=args.output,
        backup=not args.no_backup
    )
    
    if success:
        print(f"\n✅ 處理完成！")
        print(f"現在您可以使用過濾後的檔案來執行 5_generate_questions.py")
    else:
        print(f"\n❌ 處理失敗！")

if __name__ == "__main__":
    main() 