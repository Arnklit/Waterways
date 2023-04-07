# Copyright © 2021 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
tool
extends Control


onready var _progress_bar = $VBoxContainer/ProgressBar


func show_progress(message, progress) -> void:
	self.window_title = message
	_progress_bar.ratio = progress
