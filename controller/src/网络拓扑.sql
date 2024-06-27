INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (1, '181', '219.242.112.215:6182', '0000:0181');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (2, '183', '219.242.112.215.6184', '0000:0183');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (3, '185', '219.242.112.215.6186', '0000:0185');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (4, '187', '219.242.112.215.6188', '0000:0187');

INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (1,2,2,5);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (1,3,4,3);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (1,4,3,3);

INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (2,3,4,4);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (2,4,3,4);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (2,5,1,2);

INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (3,3,1,4);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (3,4,2,4);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (3,5,4,2);

INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (4,2,3,5);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (4,3,1,3);
INSERT INTO "sgwlink" ("src_sgw_id", "src_bmv2_port", "dst_sgw_id", "dst_bmv2_port") VALUES (4,4,2,3);

INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator","subnet_ip","subnet_mask") VALUES (1, '152', '219.242.112.215:6152', 1, 156,'0000:0152','10.152.0.0',16);
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator","subnet_ip","subnet_mask") VALUES (2, '153', '219.242.112.215:6153', 4, 156,'0000:0153','10.153.0.0',16);

INSERT INTO "host" ("id", "name", "ip", "mac", "cpe_id",'cpe_bmv2_port') VALUES (1, '162', '10.151.162.2', 'b8:ce:f6:9c:24:be', 1,64);
INSERT INTO "host" ("id", "name", "ip", "mac", "cpe_id",'cpe_bmv2_port') VALUES (2, '168', '10.153.168.2', 'b8:ce:f6:9c:18:a2', 2,64);

/* 路由 */
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 0, '1,2,3,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 1, '1,3,2,4');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (1, 2, 2, '1,4');

INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 0, '4,3,2,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 1, '4,2,3,1');
INSERT INTO "route" ("src_cpe_id", "dst_cpe_id", "qos", "route") VALUES (2, 1, 2, '4,1');