# ruby_rich_text_label.gd
@tool
extends RichTextLabel
class_name RubyRichTextLabel

## Base text font size
@export var base_font_size: int = 30:
	set(value):
		base_font_size = value
		_update_theme()
		_refresh_text()

## Furigana size as a percentage of base size (0.0 to 1.0)
@export_range(0.1, 1.0, 0.05) var furigana_scale: float = 0.5:
	set(value):
		furigana_scale = value
		_refresh_text()

## Horizontal spacing between ruby groups (in pixels)
@export var ruby_spacing: int = 5:
	set(value):
		ruby_spacing = value
		_refresh_text()

## Vertical offset for furigana (negative = up, positive = down)
@export var furigana_offset: int = 0:
	set(value):
		furigana_offset = value
		_refresh_text()

## The text with ruby markup
@export_multiline var ruby_text: String = "":
	set(value):
		if ruby_text != value:
			ruby_text = value
			_refresh_text()

var _is_updating: bool = false
var _last_processed: String = ""
var _valign_effect: RichTextVAlign


func _init() -> void:
	# Safe to set, but editor rendering is more reliable once we're in-tree.
	bbcode_enabled = true


func _enter_tree() -> void:
	# This runs in the editor when the node is present in an open scene.
	bbcode_enabled = true
	_setup_custom_effects()

	# In editor, make sure current text is parsed with the effect installed.
	_refresh_text()


func _ready() -> void:
	bbcode_enabled = true
	_setup_custom_effects()
	_update_theme()
	_refresh_text()


func _setup_custom_effects() -> void:
	# Create and install the valign effect
	if _valign_effect == null:
		_valign_effect = RichTextVAlign.new()

	# --- Ensure the effect exists in custom_effects (editor is picky) ---
	var found := false
	for e in custom_effects:
		if e is RichTextVAlign:
			found = true
			break

	if not found:
		# Prefer explicitly setting custom_effects so the editor sees it immediately.
		var effects := custom_effects.duplicate()
		effects.append(_valign_effect)
		custom_effects = effects

		# Also call install_effect for runtime consistency (harmless if already present).
		install_effect(_valign_effect)


func _update_theme() -> void:
	if not theme:
		theme = Theme.new()
	theme.default_font_size = base_font_size


func _refresh_text() -> void:
	if _is_updating:
		return

	# Skip if we're not ready yet
	if not is_inside_tree():
		return

	_is_updating = true

	var processed = _replace_ruby_tags(ruby_text)

	# Only update if the processed text actually changed
	if processed != _last_processed:
		_last_processed = processed
		text = processed

		# Force a re-parse / redraw (especially important in-editor)
		text = text
		queue_redraw()

	_is_updating = false


func _replace_ruby_tags(input_text: String) -> String:
	if input_text.is_empty():
		return ""

	var pattern = '\\[ruby base="([^"]+)"\\]([^\\[]+)\\[/ruby\\]'
	var regex = RegEx.new()
	regex.compile(pattern)

	var result = input_text
	var match_data = regex.search(result)

	while match_data != null:
		var base_text = match_data.get_string(1)  # The kanji/base text
		var furigana_text = match_data.get_string(2)  # The reading

		var replacement = _create_furigana_table(base_text, furigana_text)
		result = result.replace(match_data.get_string(0), replacement)
		match_data = regex.search(result, match_data.get_end())

	return result


func _create_furigana_table(kanji: String, furigana: String) -> String:
	var furigana_size = int(base_font_size * furigana_scale)

	# Wrap furigana with valign effect for vertical offset
	var furigana_content = "[font_size=%d]%s[/font_size]" % [furigana_size, furigana]

	# Apply vertical offset if specified
	if furigana_offset != 0:
		# Use int in bbcode, but the effect can parse float too.
		furigana_content = "[valign px=%d]%s[/valign]" % [furigana_offset, furigana_content]

	# [table=columns,align1,align2,inline]
	# columns=1: single column (vertical stacking)
	# l,l: left align for both cells
	# 1: inline mode (doesn't create line breaks around table)
	var table = "[table=1,l,l,1][cell]%s[/cell][cell]%s[/cell][cell padding=%d,0,0,0][/cell][/table]" % [
		furigana_content,
		kanji,
		ruby_spacing
	]

	return table


# Public API for programmatic use
func set_ruby_text(new_text: String) -> void:
	ruby_text = new_text


## Get the processed BBCode without ruby tags
func get_processed_text() -> String:
	return _replace_ruby_tags(ruby_text)
