-- dogtor.users definition

CREATE TABLE `users` (
  `id` int NOT NULL AUTO_INCREMENT,
  `email` varchar(255) NOT NULL,
  `name` varchar(255) NOT NULL,
  `photo_url` text,
  `nickname` varchar(255) DEFAULT NULL,
  `year_grade` enum('G1','G2','G3','G4','G5','G6','G7','G8','G9','G10','G11','G12','teacher','parent') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci DEFAULT NULL,
  `created_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  `introduction` text,
  `user_id` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `email` (`email`),
  UNIQUE KEY `unique_user_id` (`user_id`)
) ENGINE=InnoDB AUTO_INCREMENT=12705063 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- dogtor.chapter_list definition

CREATE TABLE `chapter_list` (
  `id` int NOT NULL AUTO_INCREMENT,
  `subject` varchar(100) NOT NULL,
  `year_grade` int NOT NULL,
  `book` varchar(100) NOT NULL,
  `chapter_num` int NOT NULL,
  `chapter_name` varchar(100) NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `subject` (`subject`(20),`chapter_name`(20))
) ENGINE=InnoDB AUTO_INCREMENT=209 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.knowledge_points definition

CREATE TABLE `knowledge_points` (
  `id` int NOT NULL AUTO_INCREMENT,
  `section_num` int NOT NULL,
  `section_name` varchar(100) NOT NULL,
  `point_name` varchar(100) NOT NULL,
  `chapter_id` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `subject` (`section_name`(20),`point_name`(20)),
  KEY `chapter_id` (`chapter_id`),
  CONSTRAINT `knowledge_points_ibfk_1` FOREIGN KEY (`chapter_id`) REFERENCES `chapter_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.questions definition


CREATE TABLE `questions` (
  `id` int NOT NULL AUTO_INCREMENT,
  `knowledge_id` int NOT NULL,
  `question_text` text NOT NULL,
  `option_1` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `option_2` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `option_3` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `option_4` text CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `correct_answer` enum('1','2','3','4') CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci NOT NULL,
  `explanation` text,
  `Error_message` text,
  PRIMARY KEY (`id`),
  KEY `knowledge_id` (`knowledge_id`),
  CONSTRAINT `questions_ibfk_1` FOREIGN KEY (`knowledge_id`) REFERENCES `knowledge_points` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=2884 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.user_question_stats definition

CREATE TABLE `user_question_stats` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` int NOT NULL,
  `question_id` int NOT NULL,
  `total_attempts` int DEFAULT '0',
  `correct_attempts` int DEFAULT '0',
  `last_attempted_at` timestamp NULL DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`,`question_id`),
  KEY `question_id` (`question_id`),
  CONSTRAINT `user_question_stats_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_question_stats_ibfk_2` FOREIGN KEY (`question_id`) REFERENCES `questions` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.user_knowledge_score definition

CREATE TABLE `user_knowledge_score` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) NOT NULL,
  `knowledge_id` int NOT NULL,
  `score` float DEFAULT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `user_id` (`user_id`,`knowledge_id`),
  KEY `knowledge_id` (`knowledge_id`),
  CONSTRAINT `fk_user_knowledge_userid` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `user_knowledge_score_ibfk_2` FOREIGN KEY (`knowledge_id`) REFERENCES `knowledge_points` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_knowledge_score_chk_1` CHECK ((`score` between 0 and 10))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.level_info definition

CREATE TABLE `level_info` (
  `id` int NOT NULL AUTO_INCREMENT,
  `chapter_id` int NOT NULL,
  `level_num` int NOT NULL,
  PRIMARY KEY (`id`),
  UNIQUE KEY `section_level_unique` (`chapter_id`,`level_num`),
  CONSTRAINT `fk_levelinfo_chapter` FOREIGN KEY (`chapter_id`) REFERENCES `chapter_list` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB AUTO_INCREMENT=142 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;


-- dogtor.user_level definition

CREATE TABLE `user_level` (
  `id` int NOT NULL AUTO_INCREMENT,
  `user_id` varchar(100) NOT NULL,
  `level_id` int NOT NULL,
  `stars` int NOT NULL,
  `answered_at` timestamp NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `level_id` (`level_id`),
  KEY `fk_user_level_userid` (`user_id`),
  CONSTRAINT `fk_user_level_userid` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `user_level_ibfk_2` FOREIGN KEY (`level_id`) REFERENCES `level_info` (`id`) ON DELETE CASCADE,
  CONSTRAINT `user_level_chk_1` CHECK ((`stars` between 0 and 3))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;