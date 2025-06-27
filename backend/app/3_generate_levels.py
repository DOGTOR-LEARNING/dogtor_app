import csv
import os
import sys
import math

def process_csv(input_file, output_file, points_per_level=3):
    """
    處理輸入的 CSV 文件並生成關卡信息的 CSV 文件
    
    參數:
    input_file -- 輸入的 CSV 文件路徑
    output_file -- 輸出的 CSV 文件路徑
    points_per_level -- 每個關卡包含的知識點數量 (默認為 3)
    """
    try:
        # 讀取輸入文件
        input_data = []
        with open(input_file, 'r', encoding='utf-8') as f:
            reader = csv.reader(f)
            # 跳過標題行（如果有）
            next(reader, None)
            for row in reader:
                if len(row) < 7:  # 確保行有足夠的列
                    print(f"警告: 跳過無效行 {row}")
                    continue
                input_data.append(row)
        
        # 準備輸出數據
        output_data = []
        level_id = 1  # 關卡編號從 1 開始
        
        # 按章節分組數據
        chapters = {}
        for row in input_data:
            # 忽略第一欄（編號）
            grade = row[1].strip()
            book = row[2].strip()
            chapter_num = row[3].strip()
            chapter_name = row[4].strip()
            
            chapter_key = f"{chapter_num}-{chapter_name}"
            if chapter_key not in chapters:
                chapters[chapter_key] = {
                    'grade': grade,
                    'book': book,
                    'chapter_num': chapter_num,
                    'chapter_name': chapter_name,
                    'sections': []
                }
            
            chapters[chapter_key]['sections'].append(row)
        
        # 處理每個章節
        for chapter_key, chapter_data in chapters.items():
            chapter_levels = []  # 存儲當前章節的所有關卡
            
            # 處理章節中的每個小節
            for row in chapter_data['sections']:
                # 解析輸入行
                grade = row[1].strip()
                book = row[2].strip()
                chapter_num = row[3].strip()
                chapter_name = row[4].strip()
                section_num = row[5].strip()
                section_name = row[6].strip()
                knowledge_points_str = row[7].strip() if len(row) > 7 else ""
                
                # 分割知識點
                if knowledge_points_str:
                    knowledge_points = [kp.strip() for kp in knowledge_points_str.split('、') if kp.strip()]
                    
                    # 如果知識點總數為 1，直接創建一個關卡
                    if len(knowledge_points) == 1:
                        level_row = [
                            str(level_id),  # 關卡編號
                            grade,
                            book,
                            chapter_num,
                            chapter_name,
                            section_num,
                            section_name,
                            knowledge_points[0],  # 關卡知識點
                            section_name,  # 關卡名稱（不加後綴）
                        ]
                        output_data.append(level_row)
                        chapter_levels.append(level_row)
                        level_id += 1
                        continue
                    
                    # 智能分配知識點，確保每個關卡有 2-3 個知識點
                    level_points_groups = []
                    remaining_points = knowledge_points.copy()
                    
                    while remaining_points:
                        # 如果剩下 4 個知識點，分成 2 組，每組 2 個
                        if len(remaining_points) == 4:
                            level_points_groups.append(remaining_points[:2])
                            level_points_groups.append(remaining_points[2:])
                            break
                        # 如果剩下 1 個知識點，將其添加到前一組
                        elif len(remaining_points) == 1:
                            if level_points_groups:
                                level_points_groups[-1].append(remaining_points[0])
                            else:
                                level_points_groups.append(remaining_points)
                            break
                        # 否則，取 3 個知識點作為一組
                        else:
                            # 如果剩下 5 個知識點，分成 3+2
                            if len(remaining_points) == 5:
                                level_points_groups.append(remaining_points[:3])
                                level_points_groups.append(remaining_points[3:])
                                break
                            # 如果剩下 2 或 3 個知識點，全部作為一組
                            elif len(remaining_points) <= 3:
                                level_points_groups.append(remaining_points)
                                break
                            else:
                                # 正常情況，取 3 個知識點
                                level_points_groups.append(remaining_points[:3])
                                remaining_points = remaining_points[3:]
                    
                    # 創建關卡
                    for i, level_points in enumerate(level_points_groups):
                        # 創建關卡名稱（直接包含後綴）
                        level_name = section_name
                        if len(level_points_groups) > 1:
                            level_name = f"{section_name}-{i+1}"
                        
                        # 創建關卡行
                        level_row = [
                            str(level_id),  # 關卡編號
                            grade,
                            book,
                            chapter_num,
                            chapter_name,
                            section_num,
                            section_name,
                            "、".join(level_points),  # 關卡知識點
                            level_name,  # 關卡名稱（已包含後綴）
                        ]
                        
                        output_data.append(level_row)
                        chapter_levels.append(level_row)
                        level_id += 1
            
            # 在章節的所有小節處理完後，添加章節總複習關卡
            if chapter_levels:
                # 創建兩個章節總複習關卡
                for i in range(1, 3):  # 創建總複習-1 和 總複習-2
                    review_level = [
                        str(level_id),  # 關卡編號
                        chapter_data['grade'],
                        chapter_data['book'],
                        chapter_data['chapter_num'],
                        chapter_data['chapter_name'],
                        "0",  # section_num 設為 0
                        "章節總複習",  # section_name
                        "章節所有知識點",  # 知識點
                        f"{chapter_data['chapter_name']} （全）-{i}",  # 關卡名稱
                    ]
                    output_data.append(review_level)
                    level_id += 1
        
        # 寫入輸出文件
        with open(output_file, 'w', encoding='utf-8', newline='') as f:
            writer = csv.writer(f)
            # 寫入標題行
            writer.writerow([
                "關卡編號", "年級", "冊數", "章節編號", "章節名稱", 
                "小節編號", "小節名稱", "知識點", "關卡名稱"
            ])
            # 寫入數據行
            writer.writerows(output_data)
        
        print(f"成功處理 {len(input_data)} 行輸入數據")
        print(f"生成了 {len(output_data)} 個關卡")
        print(f"輸出文件已保存到: {output_file}")
        
    except Exception as e:
        print(f"處理 CSV 文件時出錯: {e}")
        import traceback
        print(traceback.format_exc())
        sys.exit(1)

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("用法: python generate_levels.py <input_csv_file> [output_csv_file] [points_per_level]")
        print("  input_csv_file: 輸入的 CSV 文件路徑")
        print("  output_csv_file: 輸出的 CSV 文件路徑 (默認為 'level.csv')")
        print("  points_per_level: 每個關卡包含的知識點數量 (默認為 3)")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = sys.argv[2] if len(sys.argv) > 2 else "level.csv"
    points_per_level = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    
    if not os.path.exists(input_file):
        print(f"錯誤: 找不到輸入文件 '{input_file}'")
        sys.exit(1)
    
    process_csv(input_file, output_file, points_per_level)