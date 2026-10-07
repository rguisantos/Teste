"""Configura os caminhos locais do editor; não altera configurações do projeto."""
import json
import os
from pathlib import Path

config_root = Path(os.environ.get("XDG_CONFIG_HOME", str(Path.home() / ".config")))
config = config_root / "godot/editor_settings-4.4.tres"
sdk = os.environ.get("ANDROID_HOME") or os.environ["ANDROID_SDK_ROOT"]
java = os.environ["JAVA_HOME"]
text = config.read_text() if config.exists() else '[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
keys = {"export/android/android_sdk_path": sdk, "export/android/java_sdk_path": java}
lines = [line for line in text.splitlines() if not any(line.startswith(key + " =") for key in keys)]
lines += [f"{key} = {json.dumps(value)}" for key, value in keys.items()]
config.parent.mkdir(parents=True, exist_ok=True)
config.write_text("\n".join(lines) + "\n")
print("Editor Android configurado")
