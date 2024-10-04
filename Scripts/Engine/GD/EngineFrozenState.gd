extends Node
class_name FrozenState

var WABoard:Dictionary;
var BABoard:Dictionary;
var BPieces:Dictionary;
var IPieces:Dictionary;

func _init(wa:Dictionary, ba:Dictionary, b:Dictionary, i:Dictionary):
	WABoard = wa.duplicate(true);
	BABoard = ba.duplicate(true);
	BPieces = b.duplicate(true);
	IPieces = i.duplicate(true);
	return;
