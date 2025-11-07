-- Import this file with your MySQL client (e.g., HeidiSQL, phpMyAdmin, CLI)

CREATE TABLE IF NOT EXISTS `advanced_stashes` (
	`id` INT NOT NULL AUTO_INCREMENT,
	`label` VARCHAR(100) NOT NULL,
	`access_type` VARCHAR(20) NOT NULL,
	`job` VARCHAR(50) NULL,
	`gang` VARCHAR(50) NULL,
	`coords_json` LONGTEXT NULL,
	`stash_id` VARCHAR(100) NOT NULL,
	`radius` FLOAT NULL,
	PRIMARY KEY (`id`),
	UNIQUE KEY `uniq_stash_id` (`stash_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
