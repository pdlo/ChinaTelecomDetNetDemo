import typing

VIRTUAL_MAC = '0a:0a:0a:0a:0a:0a'

def make_variable_dict(**kwargs)-> typing.Dict[str, str]:
    return {str(k):str(v) for k,v in kwargs.items()}

def ip_to_hex(ip_address:str) -> str:
    # 将点分十进制IP地址拆分成四个部分
    octets = ip_address.split('.')
    # 将每个部分转换为十六进制并用0填充至两位
    hex_octets = [hex(int(octet))[2:].zfill(2) for octet in octets]
    # 拼接每个部分并在开头添加'0x'前缀
    hex_ip = '0x' + ''.join(hex_octets)
    return hex_ip

def mac_to_hex(mac:str):
    return '0x'+mac.replace(':','')