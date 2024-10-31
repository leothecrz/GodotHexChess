extends PopupPanel

var NOTICE_TEXT:String = "";
var POP_TIME:float = 0;
var fade_duration = 0;
var fading = false;

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var timer:Timer = $Timer;
	var text = $ColorRect/NoticeText;
	
	text.append_text(NOTICE_TEXT);
	timer.wait_time = POP_TIME/2;
	fade_duration = timer.wait_time;
	
	timer.start();
	return;

func _on_timer_timeout() -> void:
	fading = true;
	return;

func _process(delta: float) -> void:
	if not fading:
		return;
	var text = $ColorRect;
	var alpha = text.modulate.a;
	alpha -= delta / fade_duration;
	if alpha <= 0:
		alpha = 0;
		queue_free(); 
	text.modulate.a = alpha;
