extends Control


func rotate_tilemap():
	var tileMap:TileMap = $BoardTiles;
	tileMap.rotate(PI);
	tileMap.position.x *= -1;
	tileMap.position.y *= -1;

# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass



func _on_control_start_new_game(isWhite):
	print("TestTrue")
	pass # Replace with function body.
