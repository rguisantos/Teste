"""Valida funções do jogo e detecta erros de script mesmo com retorno zero."""
import os
from pathlib import Path
import subprocess
root=Path(__file__).resolve().parents[1]
godot=os.environ.get('GODOT_BIN','godot')
for script,marker in [('smoke','SMOKE_OK'),('interface','INTERFACE_OK'),('roads','ROADS_OK'),('normals','NORMALS_OK'),('grading','GRADING_OK'),('residential','RESIDENTIAL_OK'),('zoning_touch','ZONING_TOUCH_OK'),('zoning_economy','ZONING_ECONOMY_OK'),('citizen_travel','CITIZEN_TRAVEL_OK'),('pedestrian_edges','PEDESTRIAN_EDGES_OK'),('city_demand','CITY_DEMAND_OK'),('lot_management','LOT_MANAGEMENT_OK'),('lot_management_ui','LOT_MANAGEMENT_UI_OK'),('city_utilities','CITY_UTILITIES_OK'),('infrastructure_ui','INFRASTRUCTURE_UI_OK'),('demolition_network','DEMOLITION_NETWORK_OK'),('city_catalog','CITY_CATALOG_OK'),('city_sanitation','CITY_SANITATION_OK'),('sanitation_ui','SANITATION_UI_OK'),('problems_budget','PROBLEMS_BUDGET_OK'),('problems_ui','PROBLEMS_UI_OK')]:
 result=subprocess.run([godot,'--headless','--path',str(root),'--script',f'tests/{script}.gd'],capture_output=True,text=True,timeout=40)
 output=result.stdout+result.stderr
 print(output,flush=True)
 if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output or marker not in output:
  raise SystemExit(f'Falha em {script}')
result=subprocess.run([godot,'--headless','--path',str(root),'--quit-after','120'],capture_output=True,text=True,timeout=20)
output=result.stdout+result.stderr
print(output,flush=True)
if result.returncode or 'SCRIPT ERROR:' in output or 'ERROR:' in output:
 raise SystemExit('Falha na cena')
print('PROJECT_OK: controles, lotes pequenos, economia, migração e execução da cena',flush=True)
