extends Control

signal placePiece(type : GDHexConst.PIECES, isW : bool, pos : Vector2i);
signal clearPiece(pos : Vector2i);
signal clearBoard();
signal getBoardSuccess(wstarts:bool);
signal getBoardFail(reason:String);

@onready var tiles = $BoardPos;
var selected : GDHexConst.PIECES = GDHexConst.PIECES.KING;
var selectedSideW : bool = false;

var wKingPlaced = false;
var bKingPlaced = false;
var wstarts = true;
var pieceCount = 0;
var tilesList : Dictionary = {};

func resetForBuilding():
	wKingPlaced = false;
	bKingPlaced = false;
	pieceCount = 0;
	tilesList.clear();
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



func addPiece(tile):
	if(selected == GDHexConst.PIECES.KING):
		if(selectedSideW):
			if(wKingPlaced) : return;
			wKingPlaced = true;
		else:
			if(bKingPlaced) : return;
			bKingPlaced = true;
	if(tilesList.has(tile)):
		print("Piece already there");
		return;
	tilesList[tile] = selected;
	placePiece.emit(selected, selectedSideW, tile);
	pieceCount +=1;
	return;

func removePiece(tile):
	if(not tilesList.has(tile)):
		print("No piece there");
		return;
	if(tilesList[tile] == GDHexConst.PIECES.KING):
		if(selectedSideW):
			wKingPlaced = false;
		else:
			bKingPlaced = false;
	clearPiece.emit(tile);
	pieceCount -=1;
	tilesList.erase(tile);
	return;

func onButtonReleased(mouse_event : InputEventMouseButton):
	var local : Vector2 = tiles.to_local(mouse_event.global_position);
	var tile : Vector2i = tiles.local_to_map(local);
	if(GDHexConst.getAxialDistance(Vector2.ZERO, tile) > 5):
		return;
	if(selected != GDHexConst.PIECES.ZERO):
		addPiece(tile);
		return;
	removePiece(tile);
	return;

func _input(event: InputEvent) -> void:
	if(not is_processing()):
		return;
	if not (event is InputEventMouseButton):
		return;
	var mouse_event : InputEventMouseButton = event as InputEventMouseButton;
	if(mouse_event.is_pressed()):
		return;
	onButtonReleased(mouse_event);
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
	if(not (wKingPlaced and bKingPlaced)):
		getBoardFail.emit("Missing Kings");
		return;
	if(pieceCount == 2):
		getBoardFail.emit("Stale mate start. Only kings left.");
		return;
	
	getBoardSuccess.emit(wstarts);	
	return;
	
func _on_clear_pressed() -> void:
	clearBoard.emit();
	wKingPlaced = false;
	bKingPlaced = false;
	pieceCount = 0;
	tilesList.clear();
	return;


func _on_to_play_toggled(toggled_on: bool) -> void:
	wstarts = not toggled_on;
	return;
