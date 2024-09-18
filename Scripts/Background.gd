extends ColorRect

func onResize() -> void:
	print("Background Resize");
	var viewRect = get_viewport_rect();
	scale = Vector2((viewRect.size.y/642.0),(viewRect.size.y/642.0))
	#pos = -440, -254
	return;
