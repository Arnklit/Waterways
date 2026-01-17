# Copyright © 2023 Kasper Arnklit Frandsen - MIT License
# See `LICENSE.md` included in the source distribution for details.
@tool
extends Window

@onready var _progress_bar = $ProgressBar


func show_progress(message, progress) -> void:
	self.title = message
	_progress_bar.ratio = progress
