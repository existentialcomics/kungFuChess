
LOCK TABLES `players` WRITE;
/*!40000 ALTER TABLE `players` DISABLE KEYS */;
INSERT INTO `players` VALUES (-99,'SYSTEM',NULL,NULL,NULL,1600,1600,1600,1600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'2021-11-07 02:42:21','1970-01-01 05:00:00','1970-01-01 05:00:00',NULL,-200,200,'public',0,1,1,NULL),(-5,'AI Berserk',NULL,NULL,NULL,1600,1600,1600,1600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'2021-11-07 02:41:23','1970-01-01 05:00:00','1970-01-01 05:00:00',NULL,-200,200,'public',0,1,1,NULL),(-4,'AI Hard',NULL,NULL,NULL,1600,1600,1600,1600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'2021-10-12 06:04:56','1970-01-01 05:00:00','1970-01-01 05:00:00',NULL,-200,200,'public',0,1,1,NULL),(-3,'AI Medium',NULL,NULL,NULL,1600,1600,1600,1600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'2021-10-12 06:04:48','1970-01-01 05:00:00','1970-01-01 05:00:00',NULL,-200,200,'public',0,1,1,NULL),(-2,'AI Easy',NULL,NULL,NULL,1600,1600,1600,1600,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,'2021-11-07 02:41:16','1970-01-01 05:00:00','1970-01-01 05:00:00',NULL,-200,200,'public',0,1,1,NULL);
/*!40000 ALTER TABLE `players` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;
