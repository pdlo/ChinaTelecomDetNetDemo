from pathlib import Path
import toml

__all__=['config']

root=Path(__file__).parent.parent
# 加载配置
config_file=root/"config.toml"
config = toml.load(config_file)