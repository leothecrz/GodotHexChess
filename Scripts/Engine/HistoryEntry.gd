class_name HistoryEntry
extends Node



var piece : int ;
var from : Vector2i ;
var to : Vector2i ;

var enPassant : bool;
var check : bool;
var over : bool;

var promote : bool;
var pPiece:int;
var pIndex:int;

var capture : bool;
var captureTopSneak : bool;
var cPiece : int;
var cIndex : int;

func _init(PIECE : int, FROM : Vector2i, TO : Vector2i) -> void:
	piece = PIECE;
	from = Vector2i(FROM);
	to = Vector2i(TO);
	
	promote = false;
	enPassant = false;
	check = false;
	over = false;
	capture = false;
	captureTopSneak = false;
	return;

func _flipPromote() -> void:
	promote = !promote;

func _getPromote() -> bool:
	return promote;


func _flipEnPassant() -> void:
	enPassant = !enPassant;

func _getEnPassant() -> bool:
	return enPassant;


func _flipCheck() -> void:
	check = !check;

func _getCheck() -> bool:
	return check;
	
	
func _flipOver() -> void:
	over = !over;

func _getOver() -> bool:
	return over;
	

func _flipCapture() -> void:
	capture = !capture;

func _getCapture() -> bool:
	return capture;


func _getIsCaptureTopSneak() -> bool:
	return captureTopSneak;

func _flipTopSneak() -> void:
	captureTopSneak = !captureTopSneak;


func _getCPieceType() -> int:
	return cPiece

func _setCPieceType ( type:int )-> void:
	cPiece = type;


func _getCIndex () -> int:
	return cIndex

func _setCIndex ( i:int )-> void:
	cIndex = i;


func _getPPieceType() -> int:
	return pPiece

func _setPPieceType ( type:int )-> void:
	pPiece = type;


func _getPIndex () -> int:
	return pIndex

func _setPIndex ( i:int )-> void:
	pIndex = i;


func _getPiece() -> int:
	return piece;
	
func _getFrom() -> Vector2i:
	return from;
	
func _getTo() -> Vector2i:
	return to;


func _to_string():
	return "P:%d, from:(%d,%d), to:(%d,%d) -- e:%s c:%s o:%s -- p:%s type:%d index:%d -- cap:%s top:%s type:%d index:%d" % [piece, from.x, from.y, to.x, to.y, enPassant, check, over, promote, pPiece, pIndex, capture, captureTopSneak, cPiece, cIndex];
	
	
