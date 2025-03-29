import pymysql
import os
from dotenv import load_dotenv

load_dotenv()

db_password = os.getenv("DB_PASSWORD")

sql = "SELECT * FROM questions;"

# 建立連線
conn = pymysql.connect(
    host='127.0.0.1',
    port=5433,
    user='dogtor-dev',
    password=db_password,  # <<<<<< 請改成你自己的
    database='dogtor',
    charset='utf8mb4'
)

try:
    with conn.cursor() as cursor:
        # 執行查詢
        cursor.execute(sql)
        result = cursor.fetchall() #fetchone
        print(len(result))
        print(result[:10])
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