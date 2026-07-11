CREATE TABLE IF NOT EXISTS `garage_locations` (
    `id` int(11) NOT NULL AUTO_INCREMENT,
    `name` varchar(50) DEFAULT NULL,
    `type` varchar(20) DEFAULT 'garage',
    `npc` varchar(255) DEFAULT NULL,
    `spawn` varchar(255) DEFAULT NULL,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- If you already have the owned_vehicles table (standard ESX), add this column:
ALTER TABLE `owned_vehicles` ADD COLUMN IF NOT EXISTS `nickname` VARCHAR(50) NULL DEFAULT NULL;
