import pymysql
import os
from dotenv import load_dotenv
import pandas as pd

load_dotenv()

db_password = os.getenv("DB_PASSWORD")

sql = ""

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
    #cursorclass=pymysql.cursors.DictCursor  # ✅ 加上這行
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

def add_notif_token_if_not_exists():
    try:
        with conn.cursor() as cursor:
            # 先檢查欄位是否已存在
            cursor.execute("SHOW COLUMNS FROM users LIKE 'notif_token';")
            result = cursor.fetchone()

            if not result:
                alter_sql = """
                ALTER TABLE users 
                ADD COLUMN notif_token VARCHAR(255) DEFAULT NULL;
                """
                cursor.execute(alter_sql)
                conn.commit()
                print("✅ 成功新增 notif_token 欄位！")
            else:
                print("ℹ️ notif_token 欄位已存在，無需新增。")
    except Exception as e:
        print(f"❌ 執行過程中出錯: {e}")
    finally:
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
    except Exception as e:
        print(f"❌ 新增 token 欄位時發生錯誤: {e}")

# Insert missing user_heart rows
def insert_missing_user_hearts():
    try:
        # ⚠️ conn 已經在外部定義，這裡直接用
        with conn.cursor() as cursor:
            insert_sql = """
                INSERT INTO user_heart (user_id, hearts, last_updated)
                SELECT user_id, 5, NOW()
                FROM users
                WHERE user_id NOT IN (
                    SELECT user_id FROM user_heart
                );
            """
            affected_rows = cursor.execute(insert_sql)
            conn.commit()
            print(f"🎉 已插入 {affected_rows} 筆新的 user_heart 資料")
    except Exception as e:
        print(f"❌ 插入 user_heart 時發生錯誤: {e}")

# 新增 user_tokens 資料表（如不存在）
def create_user_tokens_table():
    try:
        with conn.cursor() as cursor:
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS user_tokens (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    user_id VARCHAR(50) NOT NULL,
                    firebase_token VARCHAR(255) NOT NULL,
                    device_info VARCHAR(255) DEFAULT NULL,
                    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    UNIQUE KEY uniq_token (firebase_token)
                );
            """)
            conn.commit()
            print("✅ 已建立或確認 user_tokens 資料表存在")
    except Exception as e:
        print(f"❌ 建立 user_tokens 資料表時發生錯誤: {e}")

# 新增或更新一筆 token 資料
def insert_user_token(user_id, firebase_token, device_info=None):
    try:
        with conn.cursor() as cursor:
            sql = """
                INSERT INTO user_tokens (user_id, firebase_token, device_info)
                VALUES (%s, %s, %s)
                ON DUPLICATE KEY UPDATE 
                    user_id = VALUES(user_id),
                    device_info = VALUES(device_info),
                    last_updated = CURRENT_TIMESTAMP;
            """
            cursor.execute(sql, (user_id, firebase_token, device_info))
            conn.commit()
            print(f"✅ 成功寫入 token：user_id={user_id}")
    except Exception as e:
        print(f"❌ 插入 user_token 時發生錯誤: {e}")

def query_user_tokens():
    try:
        with conn.cursor() as cursor:
            sql = """
                SELECT id, user_id, firebase_token, device_info, last_updated
                FROM user_tokens
                ORDER BY last_updated DESC;
            """
            cursor.execute(sql)
            results = cursor.fetchall()

            print("🔍 查詢結果：")
            for row in results:
                print(f"👤 User ID: {row[1]}")
                print(f"📱 Firebase Token: {row[2]}")

    except Exception as e:
        print(f"❌ 查詢 user_tokens 時發生錯誤: {e}")

def create_battle_tables():
    """創建對戰相關的資料表"""
    try:
        with conn.cursor() as cursor:
            # 1. 創建對戰歷史表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS battle_history (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    battle_id VARCHAR(50) UNIQUE NOT NULL,
                    challenger_id VARCHAR(50) NOT NULL,
                    opponent_id VARCHAR(50) NOT NULL,
                    chapter VARCHAR(100) NOT NULL,
                    subject VARCHAR(50) NOT NULL,
                    challenger_score INT DEFAULT 0,
                    opponent_score INT DEFAULT 0,
                    winner_id VARCHAR(50) DEFAULT NULL,
                    battle_data JSON DEFAULT NULL,
                    status ENUM('active', 'finished', 'cancelled') DEFAULT 'finished',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    finished_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_challenger (challenger_id),
                    INDEX idx_opponent (opponent_id),
                    INDEX idx_created_at (created_at)
                );
            """)
            
            # 2. 創建對戰詳細答題記錄表
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS battle_answers (
                    id INT AUTO_INCREMENT PRIMARY KEY,
                    battle_id VARCHAR(50) NOT NULL,
                    user_id VARCHAR(50) NOT NULL,
                    question_id INT NOT NULL,
                    question_order INT NOT NULL,
                    user_answer VARCHAR(10) NOT NULL,
                    correct_answer VARCHAR(10) NOT NULL,
                    is_correct BOOLEAN NOT NULL,
                    answer_time DECIMAL(5,2) NOT NULL,
                    score INT NOT NULL,
                    answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    INDEX idx_battle_id (battle_id),
                    INDEX idx_user_id (user_id),
                    FOREIGN KEY (question_id) REFERENCES questions(id)
                );
            """)
            
            # 3. 創建用戶在線狀態表（可選，因為已有 users.last_online）
            cursor.execute("""
                CREATE TABLE IF NOT EXISTS user_online_status (
                    user_id VARCHAR(50) PRIMARY KEY,
                    is_online BOOLEAN DEFAULT FALSE,
                    last_heartbeat TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
                    device_info VARCHAR(255) DEFAULT NULL,
                    INDEX idx_is_online (is_online),
                    INDEX idx_last_heartbeat (last_heartbeat)
                );
            """)
            
            # 4. 修改 questions 表，添加對戰模式需要的字段
            #cursor.execute("""
            #    ALTER TABLE questions 
            #    ADD COLUMN IF NOT EXISTS difficulty ENUM('easy', 'medium', 'hard') DEFAULT 'medium',
            #    ADD COLUMN IF NOT EXISTS chapter VARCHAR(100) DEFAULT NULL,
            #    ADD COLUMN IF NOT EXISTS subject VARCHAR(50) DEFAULT NULL;
            #""")
            
            conn.commit()
            print("✅ 成功創建對戰相關資料表！")
            
    except Exception as e:
        print(f"❌ 創建對戰資料表時發生錯誤: {e}")

def add_random_chapters_to_questions():
    """為現有題目隨機分配章節和科目（測試用）"""
    try:
        with conn.cursor() as cursor:
            # 獲取所有章節
            cursor.execute("SELECT subject, chapter_name FROM chapter_list")
            chapters = cursor.fetchall()
            
            if not chapters:
                print("⚠️ 沒有找到章節數據")
                return
            
            # 為沒有章節的題目隨機分配
            cursor.execute("SELECT id FROM questions WHERE chapter IS NULL OR chapter = ''")
            question_ids = cursor.fetchall()
            
            import random
            for question_id in question_ids:
                random_chapter = random.choice(chapters)
                cursor.execute("""
                    UPDATE questions 
                    SET subject = %s, chapter = %s 
                    WHERE id = %s
                """, (random_chapter[0], random_chapter[1], question_id[0]))
            
            conn.commit()
            print(f"✅ 已為 {len(question_ids)} 道題目分配章節和科目")
            
    except Exception as e:
        print(f"❌ 分配章節時發生錯誤: {e}")

def update_questions_table_structure():
    """更新 questions 表結構以支持對戰模式"""
    try:
        with conn.cursor() as cursor:
            # 檢查並添加 options JSON 欄位（如果還沒有的話）
            cursor.execute("SHOW COLUMNS FROM questions LIKE 'options'")
            if not cursor.fetchone():
                cursor.execute("""
                    ALTER TABLE questions 
                    ADD COLUMN options JSON DEFAULT NULL
                """)
                
                # 將現有的 option_1, option_2, option_3, option_4 合併到 options JSON
                cursor.execute("""
                    UPDATE questions 
                    SET options = JSON_ARRAY(
                        IFNULL(option_1, ''),
                        IFNULL(option_2, ''), 
                        IFNULL(option_3, ''),
                        IFNULL(option_4, '')
                    )
                    WHERE options IS NULL
                """)
                
                conn.commit()
                print("✅ 成功添加 options JSON 欄位並遷移數據")
            
    except Exception as e:
        print(f"❌ 更新 questions 表結構時發生錯誤: {e}")

def query_describe():
    try:
        with conn.cursor() as cursor:
            sql = """
                DESCRIBE mistakes;
            """
            cursor.execute(sql)
            results = cursor.fetchall()

            print("🔍 查詢結果：")
            print(results)

    except Exception as e:
        print(f"❌ 查詢 user_tokens 時發生錯誤: {e}")

# Query
try:
    with conn.cursor() as cursor:
        # 執行查詢
        #cursor.execute(sql)
        #result = cursor.fetchall() #fetchone
        #print(len(result))
        #print(result)
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

    # 
    #query_user_tokens()

    #query_describe()
    
    # 🆕 創建對戰相關資料表
    create_battle_tables()
    
    # 🆕 更新 questions 表結構
    # update_questions_table_structure()
    
    # 🆕 為題目分配章節（測試用）
    # add_random_chapters_to_questions()  # 取消註解來執行

    # 🆕 執行插入 user_heart 初始化（只會補漏的）
    #insert_missing_user_hearts()

    # 綁 firebase token 在 user 上
    # add_notif_token_if_not_exists()

    #create_user_tokens_table()

finally:
    conn.close()