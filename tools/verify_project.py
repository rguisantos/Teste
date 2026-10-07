"""Compatibilidade: executa a verificação atual da versão."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name("check_release.py")),run_name="__main__")
