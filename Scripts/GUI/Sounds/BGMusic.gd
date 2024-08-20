extends AudioStreamPlayer

const folder_path:String = "res://Music/";
var files:Array;

func _stopPlaying():
	stop();
	return

func selecSongAndPlay():
	if files.size() > 0:
		var random_file = files[randi() % files.size()]
		var audio_stream = load(folder_path + "/" + random_file) as AudioStream
		stream = audio_stream
		play(0);
	return;

func _continuePlaying():
	selecSongAndPlay();
	return

# Called when the node enters the scene tree for the first time.
func _ready():
	var dir = DirAccess.open(folder_path)
	if dir:
		files = []
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if not dir.current_is_dir() and file_name.ends_with(".mp3"):
				files.append(file_name)
			file_name = dir.get_next()
		
		dir.list_dir_end()
	selecSongAndPlay();
	return;

func _on_finished():
	stream = null;
	selecSongAndPlay()
	pass # Replace with function body.
