@tool
extends Window

@onready var _progress_bar = $ProgressBar


func show_progress(message, progress) -> void:
	self.title = message
	_progress_bar.ratio = progress
