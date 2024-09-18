extends Control

func onResize() -> void:
	var viewRect = get_viewport_rect();
	scale = Vector2((viewRect.size.y/642.0),(viewRect.size.y/642.0))
	return;
