INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (1, '182', '219.242.112.215:6182', '0000:0182');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (2, '184', '219.242.112.215.6184', '0000:0184');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (3, '186', '219.242.112.215.6186', '0000:0186');
INSERT INTO "sgw" ("id", "name", "console_ip", "srv6_locator") VALUES (4, '188', '219.242.112.215.6188', '0000:0188');

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

INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (1, 1, 1, 2, 5);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (2, 1, 2, 4, 11);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (3, 2, 6, 3, 8);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (4, 3, 7, 4, 10);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (5, 2, 5, 1, 1);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (6, 4, 11, 1, 2);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (7, 3, 8, 2, 6);
INSERT INTO "sgwlink" ("id", "sgw_id_1", "interface_id_1", "sgw_id_2", "interface_id_2") VALUES (8, 4, 10, 3, 7);


/*cpe对应的端口号还未确定，确定后需要更改*/
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator") VALUES (1, '151', '219.242.112.215:6151', 1, 172,'0000:0151');
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator") VALUES (2, '152', '219.242.112.215:6152', 3, 172,'0000:0152');
INSERT INTO "cpe" ("id", "name", "console_ip", "connect_sgw","port_to_sgw", "srv6_locator") VALUES (3, '153', '219.242.112.215:6153', 4, 172,'0000:0153');

INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (1, 1, 2, 0, '1,2,3');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (2, 1, 2, 1, '1,4,3');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (3, 1, 3, 0, '1,2,3,4');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (4, 1, 3, 1, '1,4');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (5, 2, 3, 0, '3,2,1,4');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (6, 2, 3, 1, '3,4');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (7, 2, 1, 0, '3,2,1');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (8, 2, 1, 1, '3,1,4');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (9, 3, 1, 0, '4.3.2.1');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (10, 3, 1, 1, '4,1');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (11, 3, 2, 0, '4,1,2,3');
INSERT INTO "route" ("id", "src_cpe_id", "dst_cpe_id", "tos", "route") VALUES (12, 3, 2, 1, '4,3');

INSERT INTO "host" ("id", "name", "ip", "cpe_id") VALUES (1, '162', '10.151.162.2', 1);
INSERT INTO "host" ("id", "name", "ip", "cpe_id") VALUES (2, '166', '10.152.166.2', 2);
INSERT INTO "host" ("id", "name", "ip", "cpe_id") VALUES (3, '168', '10.153.168.2', 3);
