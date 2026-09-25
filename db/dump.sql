-- Todo App Database
-- Compatible with MySQL 8.x

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

SET NAMES utf8mb4;

CREATE DATABASE IF NOT EXISTS `todo_app`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_0900_ai_ci;

USE `todo_app`;

DROP TABLE IF EXISTS `todos`;

CREATE TABLE `todos` (
    `_id` INT NOT NULL AUTO_INCREMENT,
    `todo` VARCHAR(255) NOT NULL,
    PRIMARY KEY (`_id`)
) ENGINE=InnoDB
  DEFAULT CHARSET=utf8mb4
  COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO `todos` (`todo`) VALUES
('I will wake up at 4 in the morning.'),
('I will practice Docker for 1 hour.'),
('I will practice JavaScript for 2 hours.'),
('Then I will have breakfast.'),
('I will practice PHP for 3 hours.');