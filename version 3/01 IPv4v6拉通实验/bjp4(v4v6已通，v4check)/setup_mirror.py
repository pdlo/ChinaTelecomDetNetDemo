#
# Simple mirror session setup script
#

print("Mirror Destination 1 -- sending to port 9")
mirror.session_create(
    mirror.MirrorSessionInfo_t(
        mir_type=mirror.MirrorType_e.PD_MIRROR_TYPE_NORM,
        direction=mirror.Direction_e.PD_DIR_BOTH,
        mir_id=1,
        egr_port=56, egr_port_v=True,
        max_pkt_len=16384))

conn_mgr.complete_operations()
