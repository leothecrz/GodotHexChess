extends Object;
class_name BitBoard;

##
# Ignore Sign Bit
# 64th index is 1st bit of front
# final index is 28th bit of front

const COLUMN_SIZES:Array = [6,7,8,9,10,11,10,9,8,7,6];
const COLUMN_MIN_R:Array = [0, -1, -2, -3, -4, -5, -5, -5, -5, -5, -5];
const COLUMN_MAX_R:Array = [5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0];

const BLACK_CORNER =  1125899906842624;
const WHITE_CORNER =  1099511627776;
const CENTER = 35184372088832;

const START = 0;
const END_FRONT = 0;

const INDEX_TRANSITION = 62;
const INDEX_OFFSET = 63;

var Front:int;
var Back:int;

##
static func inBitBoardRange(qpos:int, rpos:int):
	return ( (-5 <= qpos) && (qpos <= 5) && (BitBoard.COLUMN_MIN_R[qpos + 5] <= rpos) && (rpos <= BitBoard.COLUMN_MAX_R[qpos + 5] ) )

##
static func CREATE_FULL_MASK() -> BitBoard:
	return BitBoard.new(MinMaxAI.MAX_INT, MinMaxAI.MAX_INT);

##
func _init(front:int=0, back:int=0):
	Front = front;
	Back = back;
	return;

##
func _getF():
	return Front;

##
func _getB():
	return Back;

##
func XOR(to:BitBoard) -> BitBoard:
	return BitBoard.new(Front ^ to._getF(), Back ^ to._getB());

##
func OR(to:BitBoard) -> BitBoard:
	return BitBoard.new(Front | to._getF(), Back | to._getB());

##
func AND(to:BitBoard) -> BitBoard:
	return BitBoard.new(Front & to._getF(), Back & to._getB());

##
func EQUAL(to:BitBoard) -> bool:
	return (Front ^ to._getF() == 0) and (Back ^ to._getB() == 0);

##
func IS_EMPTY() -> bool:
	return (Back == 0) and (Front == 0);

func _getCopy():
	return BitBoard.new(_getF(), _getB());

func _getIndexes() -> Array:
	var b = _getB();
	var f = _getF();
	var indexes = [];
	var index:int = 0;
	while(b > 0b0):
		if (b & 0b1) > 0:
			indexes.append(index);
		b >>= 1;
		index += 1;
	index = 63;
	while(f > 0b0):
		if (f & 0b1) > 0:
			indexes.append(index);
		f >>= 1;
		index += 1;
	return indexes;

##
func _to_string():
	return "%s %s" % [String.num_int64(Front,2).pad_zeros(32), String.num_int64(Back,2).pad_zeros(63)];

##
func _to_string_nonBin():
	return "%d %d" % [Front, Back];
