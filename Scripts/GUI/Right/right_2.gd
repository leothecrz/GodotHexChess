extends Control

signal placePiece(type : GDHexConst.PIECES, isW : bool, pos : Vector2i);
signal clearPiece(pos : Vector2i);
signal clearBoard();

@onready var tiles = $BoardPos;
var selected : GDHexConst.PIECES = GDHexConst.PIECES.PAWN;
var selectedSideW : bool = false;

var wKingPlaced = false;
var bKingPlaced = false;


func resetForBuilding():
	wKingPlaced = false;
	bKingPlaced = false;
	return;

func __swapModes() -> void:
	set_process(not is_processing())
	visible = not visible;
	
	if(visible):
		resetForBuilding();
	return;

func _ready() -> void:
	set_process(false);
	visible = false;
	return;

func _input(event: InputEvent) -> void:
	if(not is_processing()):
		return;
	if not event is InputEventMouseButton:
		return;
	var mouse_event : InputEventMouseButton = event as InputEventMouseButton;
	if(mouse_event.is_pressed()):
		return;
	var local = tiles.to_local(mouse_event.global_position);
	var tile = tiles.local_to_map(local);
	if(GDHexConst.getAxialDistance(Vector2.ZERO, tile) > 5):
		return;
	
	print(tile);
	print("In of board")
	
	if(selected != GDHexConst.PIECES.ZERO):
		if(selected == GDHexConst.PIECES.KING):
			if(selectedSideW):
				if(wKingPlaced) : return;
				wKingPlaced = true;
			else:
				if(bKingPlaced) : return;
				bKingPlaced = true;
		placePiece.emit(selected, selectedSideW, tile);
	else:
		clearPiece.emit(tile);
	return;
	
func _process(_delta: float) -> void:
	return;



## GUI SIGNAL RECIVE
func _on_pawn_pressed() -> void:
	selected = GDHexConst.PIECES.PAWN;
	return;
func _on_knight_pressed() -> void:
	selected = GDHexConst.PIECES.KNIGHT;
	return;
func _on_bishop_pressed() -> void:
	selected = GDHexConst.PIECES.BISHOP;
	return;
func _on_rook_pressed() -> void:
	selected = GDHexConst.PIECES.ROOK;
	return;
func _on_queen_pressed() -> void:
	selected = GDHexConst.PIECES.QUEEN;
	return;
func _on_king_pressed() -> void:
	selected = GDHexConst.PIECES.KING;
	return;
func _on_erase_pressed() -> void:
	selected = GDHexConst.PIECES.ZERO;
	return;
func _on_side_select_toggled(toggled_on: bool) -> void:
	selectedSideW = toggled_on;
	return;

func _on_get_pressed() -> void:
	return;
	
func _on_clear_pressed() -> void:
	clearBoard.emit();
	wKingPlaced = false;
	bKingPlaced = false;
	return;
