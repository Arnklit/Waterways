tool
extends Control


onready var _progress_bar = $VBoxContainer/ProgressBar


func show_progress(message, progress) -> void:
	self.window_title = message
	_progress_bar.ratio = progress
