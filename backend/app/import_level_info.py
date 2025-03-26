import csv
import pymysql
import os
from dotenv import load_dotenv

# 載入環境變數
load_dotenv()

# 數據庫連接配置
DB_HOST = os.getenv("DB_HOST")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_NAME = os.getenv("DB_NAME")

def get_db_connection():
    """建立與數據庫的連接"""
    return pymysql.connect(
        host=DB_HOST,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        charset='utf8mb4',
        cursorclass=pymysql.cursors.DictCursor
    )

def import_level_info(csv_file_path):
    """從 CSV 檔案導入關卡資訊到數據庫"""
    connection = get_db_connection()
    
    try:
        with connection.cursor() as cursor:
            # 設置連接的字符集
            cursor.execute("SET NAMES utf8mb4")
            cursor.execute("SET CHARACTER SET utf8mb4")
            cursor.execute("SET character_set_connection=utf8mb4")
            
            # 讀取 CSV 檔案
            with open(csv_file_path, 'r', encoding='utf-8') as file:
                csv_reader = csv.DictReader(file)
                
                # 遍歷每一行數據
                for row in csv_reader:
                    # 查找章節 ID
                    chapter_sql = """
                    SELECT id FROM chapter_list 
                    WHERE year_grade = %s 
                    AND chapter_name = %s
                    """
                    cursor.execute(chapter_sql, (
                        row['年級'],
                        row['章節名稱']
                    ))
                    chapter_result = cursor.fetchone()
                    
                    if not chapter_result:
                        print(f"找不到章節: 年級={row['年級']}, 章節名稱={row['章節名稱']}")
                        continue
                    
                    chapter_id = chapter_result['id']
                    
                    # 檢查關卡是否存在
                    level_sql = """
                    SELECT id FROM level_info 
                    WHERE chapter_id = %s 
                    AND level_num = %s
                    """
                    cursor.execute(level_sql, (
                        chapter_id,
                        row['關卡編號']
                    ))
                    level_result = cursor.fetchone()
                    
                    if not level_result:
                        # 創建新關卡
                        insert_level_sql = """
                        INSERT INTO level_info (chapter_id, level_num)
                        VALUES (%s, %s)
                        """
                        cursor.execute(insert_level_sql, (
                            chapter_id,
                            row['關卡編號']
                        ))
                        connection.commit()
                        print(f"已創建關卡: 章節ID={chapter_id}, 關卡編號={row['關卡編號']} (ID: {cursor.lastrowid})")
                    else:
                        print(f"關卡已存在: 章節ID={chapter_id}, 關卡編號={row['關卡編號']} (ID: {level_result['id']})")
            
            print("關卡資訊導入完成！")
    
    except Exception as e:
        print(f"導入過程中出錯: {str(e)}")
        import traceback
        print(traceback.format_exc())
    
    finally:
        connection.close()

if __name__ == "__main__":
    # CSV 檔案路徑
    csv_file_path = "junior_science_level.csv"
    
    # 導入關卡資訊
    import_level_info(csv_file_path)