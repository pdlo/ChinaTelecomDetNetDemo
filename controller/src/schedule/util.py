import logging
import toml
from pathlib import Path

config_file=Path(__file__).parent.parent.parent/"config.toml"

config = toml.load(config_file)