extends RefCounted
## Medições observadas; sem inferir desempenho a partir do modelo do celular.

const MAX_SAMPLES := 1800
var frame_ms: Array[float] = []
var elapsed := 0.0


func record(delta: float) -> void:
	elapsed += delta
	frame_ms.append(delta * 1000)
	if frame_ms.size() > MAX_SAMPLES:
		frame_ms.pop_front()


func reset() -> void:
	frame_ms.clear()
	elapsed = 0


func snapshot(seed_value: int, shadows: bool, viewport_size: Vector2i) -> Dictionary:
	var sorted := frame_ms.duplicate()
	sorted.sort()
	var sum := 0.0
	for sample in sorted:
		sum += sample
	var mean := sum / maxi(sorted.size(), 1)
	var p95 := 0.0
	if not sorted.is_empty():
		p95 = sorted[mini(int(ceil(sorted.size() * 0.95)) - 1, sorted.size() - 1)]
	return {
		"prototype_version": "0.0.19",
		"godot": Engine.get_version_info().get("string", ""),
		"os": OS.get_name(),
		"os_version": OS.get_version(),
		"device_model": OS.get_model_name(),
		"renderer": RenderingServer.get_current_rendering_method(),
		"gpu": RenderingServer.get_video_adapter_name(),
		"viewport": {"width": viewport_size.x, "height": viewport_size.y},
		"seed": seed_value,
		"population": 0,
		"shadows": shadows,
		"duration_seconds": snappedf(elapsed, 0.01),
		"sample_count": sorted.size(),
		"fps_current": Engine.get_frames_per_second(),
		"fps_sample_mean": snappedf(1000 / maxf(mean, 0.001), 0.1),
		"frame_ms_mean": snappedf(mean, 0.01),
		"frame_ms_p95": snappedf(p95, 0.01),
		"static_memory_mb": snappedf(OS.get_static_memory_usage() / 1048576.0, 0.1),
		"notes": "Memória estática não é o consumo total do aplicativo. Últimos 1800 quadros."
	}
