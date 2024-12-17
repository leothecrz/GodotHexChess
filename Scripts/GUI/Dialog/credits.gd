extends ColorRect

const creditsDir = "res://Credits/";

@onready var textRef = $CreditsText;


func _ready() -> void:
	load_credits();
	return;

func load_credits():
	var dir = DirAccess.open(creditsDir);
	if dir != null:
		dir.list_dir_begin()
		var file_name : String = dir.get_next();
		var combined_text : String = "";
		while (file_name != ""):
			if (file_name.ends_with(".txt")):
				var file_path = creditsDir + file_name;
				if (FileAccess.file_exists(file_path)):
					var file = FileAccess.open(file_path, FileAccess.READ);
					combined_text +=  "[center]" + file_name.left(-4) + " :\n " + file.get_as_text() + "[/center]" + "\n\n";
					file.close();
			file_name = dir.get_next();
		dir.list_dir_end();
		textRef.text += combined_text;
	return;
