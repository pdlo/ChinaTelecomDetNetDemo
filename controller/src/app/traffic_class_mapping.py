#映射
def mapping_to_qos(delay):
    if delay <= 30:
        return 2
    elif 30 <= delay <= 40:
        return 1
    else:
        return 0
