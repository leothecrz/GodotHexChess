extends ColorRect

func onResize() -> void:
	var viewRect = get_viewport_rect();
	pivot_offset = size/2;
	scale = Vector2((viewRect.size.y/642.0),(viewRect.size.y/642.0))
	#pos = -440, -254
	
	return;
