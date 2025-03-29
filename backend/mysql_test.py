import pymysql
import os
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

db_password = os.getenv("DB_PASSWORD")

sql = "SELECT * FROM knowledge_points;"

csv_file_path = '/Users/bowen/Desktop/NTU/Grade2-2/DOGTOR/junior_civ_chapter.csv'  # 替換為您的 CSV 檔案路徑
df = pd.read_csv(csv_file_path)

# 建立連線
conn = pymysql.connect(
    host='127.0.0.1',
    port=5433,
    user='dogtor-dev',
    password=db_password,  # <<<<<< 請改成你自己的
    database='dogtor',
    charset='utf8mb4'
)

# Modify table
def modify_table():
    try:
        with conn.cursor() as cursor:
                # 例如，修改資料表的欄位大小
                alter_sql = """
                ALTER TABLE knowledge_points 
                MODIFY COLUMN point_name VARCHAR(500);
                """
                cursor.execute(alter_sql)
                conn.commit()
                print("資料表修改成功！")
    except Exception as e:
        print(f"執行指令時出錯: {str(e)}")
    finally:
        if conn:
            conn.close()

# Insert into chapter_list
def insert_chapter_list():
    try:
        with conn.cursor() as cursor:
            # 檢查 CSV 中的欄位是否與資料表中的欄位對應
            columns = ['subject', 'year_grade', 'book', 'chapter_num', 'chapter_name']
            for index, row in df.iterrows():
                # 準備 SQL 插入語句
                sql = """
                    INSERT IGNORE INTO chapter_list (subject, year_grade, book, chapter_num, chapter_name)
                    VALUES (%s, %s, %s, %s, %s);
                """
                # 執行插入操作
                cursor.execute(sql, (row['subject'], row['year_grade'], row['book'], row['chapter_num'], row['chapter_name']))
            
            # 提交更改
            conn.commit()
            print(f"已成功將 {len(df)} 筆資料寫入 chapter_list 資料表")
    finally:
        conn.close()

# Query

try:
    with conn.cursor() as cursor:
        # 執行查詢
        cursor.execute(sql)
        result = cursor.fetchall() #fetchone
        print(len(result))
        print(result)
        #print("✅ 成功連線！目前時間：", result[0])

        cursor.execute("SHOW TABLES;")
        tables = cursor.fetchall()
        
        for table in tables:
            table_name = table[0]
            print(f"資料表：{table_name}")
            
            # 獲取該資料表的所有欄位名稱
            cursor.execute(f"DESCRIBE {table_name}")
            columns = cursor.fetchall()
            column_names = [column[0] for column in columns]
            print("欄位名稱：", column_names)
            print("-" * 50)

finally:
    conn.close()