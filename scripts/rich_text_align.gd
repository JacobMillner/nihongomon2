# rich_text_valign.gd
@tool
class_name RichTextVAlign
extends RichTextEffect

# BBCode tag name: [valign px=px]text[/valign]
var bbcode := "valign"

func _process_custom_fx(char_fx: CharFXTransform) -> bool:
	# Get the pixel offset from the tag parameter
	var offset_px = char_fx.env.get("px", 0.0)
	
	# Move characters vertically (negative = up, positive = down)
	char_fx.offset = Vector2.UP * offset_px
	
	return true
