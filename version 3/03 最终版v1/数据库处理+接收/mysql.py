import logging


def create_table(conn,cursor):
    cursor.execute("drop database if exists INTdata")
    cursor.execute("create database INTdata")
    cursor.execute("use INTdata")
    cursor.execute("""
        CREATE TABLE `links` (
          `link_id` int NOT NULL AUTO_INCREMENT,
          `switch_from_port` int NOT NULL,
          `switch_to_port` int NOT NULL,
          PRIMARY KEY (`link_id`)
        ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci""")
    cursor.execute(
        """
                CREATE TABLE `middle` (
                    `id` int NOT NULL primary key AUTO_INCREMENT,
                  `time_1` bigint NOT NULL,
                  `time_2` bigint NOT NULL,
                  `packet_len_egress` int NOT NULL,
                  `packet_len_ingress` int NOT NULL
                ) ENGINE=InnoDB AUTO_INCREMENT=1 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci"""
    )
    cursor.execute("""
        CREATE TABLE `intdata` (
         ID int not null primary key auto_increment,
          `link_id` int NOT NULL,
          `delay` bigint DEFAULT NULL,
          `throughput_egress` float NOT NULL,
          `throughput_ingress` float NOT NULL,
          KEY `link_id` (`link_id`),
          CONSTRAINT `intdata_ibfk_1` FOREIGN KEY (`link_id`) REFERENCES `links` (`link_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci""")
    cursor.execute("SHOW DATABASES")
    databases = cursor.fetchall()
    logging.info("Databases:")
    for db in databases:
        if "intdata" in db:
            logging.info(db)

    cursor.execute("USE INTdata")
    cursor.execute("SHOW TABLES")
    tables = cursor.fetchall()
    logging.info("Tables in INTdata:")
    for table in tables:
        if "intdata" in table or "links" in table or "middle" in table:
            logging.info(table)
    conn.commit()


def deal_data(conn,cursor,list):
    for i in range(0,len(list)-1):
        switch_from_port=list[i].port_egress
        switch_to_port=list[i+1].port_ingress
        sql="select * from links where switch_from_port=%s and switch_to_port=%s "
        cursor.execute(sql,(switch_from_port,switch_to_port))
        result=cursor.fetchall()
        if len(result)==0:
            sql=("insert into links ( switch_from_port,  switch_to_port) VALUES "
                 "(%s,%s)")
            cursor.execute(sql,(switch_from_port,switch_to_port))
            conn.commit()
#-------------------------------------------------------有几条链路
        time1=list[i].current_time_ingress
        time2=list[i+1].current_time_ingress
        packet_len_egress=list[i].packet_len_egress
        packet_len_ingress=list[i+1].packet_len_ingress
        sql="SELECT COUNT(*) FROM middle"
        cursor.execute(sql)
        result = cursor.fetchone()
        # 获取统计结果
        row_count = result[0]
        if row_count==0:
            sql=("insert into middle (time_1, time_2,packet_len_egress,packet_len_ingress) VALUES "
                 "(%s,%s,%s,%s)")
            cursor.execute(sql,(time1,time2,packet_len_egress,packet_len_ingress))
            conn.commit()
        elif row_count==2:
            sql=("TRUNCATE TABLE middle")
            cursor.execute(sql)
            sql = ("insert into middle (time_1, time_2,packet_len_egress,packet_len_ingress) VALUES "
                   "(%s,%s,%s,%s)")
            cursor.execute(sql, (time1, time2, packet_len_egress, packet_len_ingress))
            conn.commit()
        elif row_count==1:
            sql = ("insert into middle (time_1, time_2,packet_len_egress,packet_len_ingress) VALUES "
                   "(%s,%s,%s,%s)")
            cursor.execute(sql, (time1, time2, packet_len_egress, packet_len_ingress))
            conn.commit()
            sql="select * from middle where id=1 or id=2"
            cursor.execute(sql)

            # 获取查询结果
            results = cursor.fetchall()
            #ogging.info(results[0])
            time1before=results[0][1]
            time2before=results[0][2]
            packet_len_egressbefore=results[0][3]
            packet_len_ingressbefore=results[0][4]
            time1after = results[1][1]
            time2after = results[1][2]
            packet_len_egressafter = results[1][3]
            packet_len_ingressafter = results[1][4]
            delay=time2after-time1after
            throughput_egress=abs((packet_len_egressafter-packet_len_egressbefore)/(time2after-time2before)*1000)
            throughput_ingress=abs(packet_len_ingressafter-packet_len_ingressbefore/(time1after-time1before)*1000)
            sql = "select link_id from links where switch_from_port=%s  and switch_to_port=%s"
            cursor.execute(sql, ( switch_from_port,  switch_to_port))
            result = cursor.fetchone()
            if result:
                link_id = result[0]
                sql = ("insert into intdata (link_id, delay, throughput_egress, throughput_ingress) VALUES "
                       "(%s,%s,%s,%s)")
                cursor.execute(sql, (link_id, delay, throughput_egress, throughput_ingress))
                conn.commit()


