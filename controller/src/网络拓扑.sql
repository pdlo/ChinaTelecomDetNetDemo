INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (1, '181', '219.242.112.215:6182', '0000:0181');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (2, '183', '219.242.112.215.6184', '0000:0183');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (3, '185', '219.242.112.215.6186', '0000:0185');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (4, '187', '219.242.112.215.6188', '0000:0187');

INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (1, 'ens2f0', 1, 1);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (2, 'ens2f2', 1, 2);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (3, 'ens1f3', 1, 3);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (4, 'ens1f3', 2, 0);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (5, 'eth2', 2, 1);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (6, 'ens2f2', 2, 2);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (7, 'eth2', 3, 1);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (8, 'ens2f2', 3, 2);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (9, 'ens1f3', 3, 3);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (10, 'eth2', 4, 1);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (11, 'ens2f2', 4, 2);
INSERT INTO "sgwinterface" ("id", "name", "sgw_id", "bmv2_port") VALUES (12, 'ens1f3', 4, 3);

INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (1, 1,1,2,1);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (2, 1,2,4,2);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (3, 2,2,3,2);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (4, 3,1,4,1);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (5, 2,1,1,1);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (6, 4,2,1,2);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (7, 3,2,2,2);
INSERT INTO "sgwlink" ("id", "src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (8, 4,1,3,1);

INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator","subnet_ip","subnet_mask") VALUES (1, '151', '219.242.112.215:6151', 1, 156,'0000:0151','10.151.0.0',16);
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator","subnet_ip","subnet_mask") VALUES (2, '152', '219.242.112.215:6152', 3, 156,'0000:0152','10.152.0.0',16);
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator","subnet_ip","subnet_mask") VALUES (3, '153', '219.242.112.215:6153', 4, 156,'0000:0153','10.153.0.0',16);

INSERT INTO "host" ("id", "name", "ip", "mac", "cpe_id",'cpe_bmv2_port') VALUES (1, '162', '10.153.162.2', 'b8:ce:f6:9c:24:be', 3,64);
INSERT INTO "host" ("id", "name", "ip", "mac", "cpe_id",'cpe_bmv2_port') VALUES (2, '166', '10.152.166.2', 'b8:ce:f6:9c:18:a2', 2,64);
INSERT INTO "host" ("id", "name", "ip", "mac", "cpe_id",'cpe_bmv2_port') VALUES (3, '168', '10.151.168.2', 'b8:ce:f6:9c:26:62', 1,64);


/* 路由 */
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 0, '3,1,2,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 1, '3,1,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 2, '3,4');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 3, 0, '3,4,2,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 3, 1, '3,2,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 3, 2, '3,1');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 3, 0, '4,3,2,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 3, 1, '4,2,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 3, 2, '4,1');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 0, '4,2,1,3');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 1, '4,1,3');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 2, '4,3');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 1, 0, '1,2,4,3');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 1, 1, '1,2,3');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 1, 2, '1,3');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 2, 0, '1,2,3,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 2, 1, '1,2,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (3, 2, 2, '1,4');