-- 初始化資料庫腳本
USE dogtor;

-- 創建基本表格（如果不存在）
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id VARCHAR(255) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(255),
    photo_url TEXT,
    nickname VARCHAR(100),
    year_grade VARCHAR(50),
    introduction TEXT,
    notif_token TEXT,
    last_online TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 愛心系統表
CREATE TABLE IF NOT EXISTS user_heart (
    user_id VARCHAR(255) PRIMARY KEY,
    hearts INT DEFAULT 5,
    last_updated TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 對戰系統表
CREATE TABLE IF NOT EXISTS battle_history (
    id INT AUTO_INCREMENT PRIMARY KEY,
    battle_id VARCHAR(255) UNIQUE NOT NULL,
    player1_id VARCHAR(255) NOT NULL,
    player2_id VARCHAR(255) NOT NULL,
    subject VARCHAR(100) NOT NULL,
    chapter VARCHAR(200) NOT NULL,
    player1_score INT DEFAULT 0,
    player2_score INT DEFAULT 0,
    winner_id VARCHAR(255),
    status ENUM('waiting', 'in_progress', 'completed', 'cancelled') DEFAULT 'waiting',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    completed_at TIMESTAMP NULL
);

CREATE TABLE IF NOT EXISTS battle_answers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    battle_id VARCHAR(255) NOT NULL,
    user_id VARCHAR(255) NOT NULL,
    question_id INT NOT NULL,
    user_answer VARCHAR(10),
    is_correct BOOLEAN DEFAULT FALSE,
    answer_time FLOAT DEFAULT 0,
    points_earned INT DEFAULT 0,
    answered_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (battle_id) REFERENCES battle_history(battle_id) ON DELETE CASCADE
);

-- 在線狀態表
CREATE TABLE IF NOT EXISTS user_online_status (
    user_id VARCHAR(255) PRIMARY KEY,
    is_online BOOLEAN DEFAULT FALSE,
    last_seen TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- 好友系統表
CREATE TABLE IF NOT EXISTS friendships (
    id INT AUTO_INCREMENT PRIMARY KEY,
    requester_id VARCHAR(255) NOT NULL,
    addressee_id VARCHAR(255) NOT NULL,
    status ENUM('pending','accepted','rejected','blocked') DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_friendship (requester_id, addressee_id)
);

-- 插入測試數據
INSERT IGNORE INTO users (user_id, email, name, nickname) VALUES 
('test_user_1', 'test1@example.com', 'Test User 1', 'Tester1'),
('test_user_2', 'test2@example.com', 'Test User 2', 'Tester2');

INSERT IGNORE INTO user_heart (user_id, hearts) VALUES 
('test_user_1', 5),
('test_user_2', 3);

INSERT IGNORE INTO user_online_status (user_id, is_online) VALUES 
('test_user_1', TRUE),
('test_user_2', FALSE);