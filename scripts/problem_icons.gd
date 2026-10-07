extends RefCounted
## Ícones vetoriais originais, compartilhados pelo mapa e pela lista.
static var textures:Dictionary={}
static func texture(code:String)->Texture2D:
	if textures.has(code): return textures[code]
	var paths:={
		"water":"M12 2C9 7 5 11 5 15A7 7 0 0 0 19 15C19 11 15 7 12 2Z",
		"source":"M12 2C9 7 5 11 5 15A7 7 0 0 0 19 15C19 11 15 7 12 2Z",
		"power":"M13 2L4 14H11L9 22L21 9H13Z",
		"sewage":"M3 3V10H11V3M7 10V14M2 17Q5 14 8 17T14 17T22 17M2 22Q5 19 8 22T14 22T22 22",
		"access":"M7 2L4 22M17 2L20 22M12 2V8M12 16V22M8 10L16 14M16 10L8 14",
		"isolated":"M3 4H8V9H3ZM16 15H21V20H16ZM8 7L11 10M13 14L16 17M10 15L15 10",
		"demand":"M3 21H21M5 17V11H9V17M12 17V7H16V17M19 17V3",
		"workers":"M4 20V15Q4 12 8 12Q12 12 12 15V20M15 20V15Q15 12 19 12M11 6A3 3 0 1 0 5 6A3 3 0 1 0 11 6M22 6A3 3 0 1 0 16 6A3 3 0 1 0 22 6",
		"alert":"M12 2L23 22H1ZM12 8V14M12 18V19"
	}
	var colors:={"water":"#48c7ff","source":"#48c7ff","power":"#ffd25c","sewage":"#52e0b1","access":"#ff7777","isolated":"#ffae65","demand":"#b69aff","workers":"#b69aff","alert":"#ffd25c"}
	var filled:bool=code in ["water","source","power"]
	var svg:="<svg xmlns='http://www.w3.org/2000/svg' width='28' height='28' viewBox='0 0 24 24'><path d='%s' fill='%s' stroke='%s' stroke-width='1.8' stroke-linecap='round' stroke-linejoin='round'/></svg>" % [paths.get(code,paths.alert),colors.get(code,"#ffd25c") if filled else "none",colors.get(code,"#ffd25c")]
	var image:=Image.new()
	if image.load_svg_from_string(svg)!=OK: return null
	textures[code]=ImageTexture.create_from_image(image)
	return textures[code]
