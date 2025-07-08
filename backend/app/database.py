"""
資料庫連接配置
"""
import os
import pymysql
from typing import Optional


def get_db_connection():
    """取得資料庫連接"""
    # 檢測運行環境
    if os.getenv('K_SERVICE'):  # 在 Cloud Run 中運行
        # 使用 Unix socket 連接到 Cloud SQL
        instance_connection_name = os.getenv('INSTANCE_CONNECTION_NAME')
        return pymysql.connect(
            unix_socket=f'/cloudsql/{instance_connection_name}',
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            db=os.getenv('DB_NAME'),
            charset='utf8mb4',
            use_unicode=True,
            init_command='SET NAMES utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
    else:  # 本地開發環境
        # 使用 TCP 連接到資料庫
        return pymysql.connect(
            host='localhost',  # 本地開發時使用的主機
            user=os.getenv('DB_USER'),
            password=os.getenv('DB_PASSWORD'),
            db=os.getenv('DB_NAME'),
            charset='utf8mb4',
            use_unicode=True,
            init_command='SET NAMES utf8mb4',
            cursorclass=pymysql.cursors.DictCursor
        )
