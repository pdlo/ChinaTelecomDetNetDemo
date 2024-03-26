#映射
def mapping(delay):
    if delay <= 30:
        return 3
    elif 30 <= delay <= 40:
        return 2
    else:
        return 1
