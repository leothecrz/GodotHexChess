extends Object;
class_name BitBoard;

##
# Ignore Sign Bit
# 64th index is 1st bit of front
# final index is 28th bit of front

const COLUMN_SIZES:Array = [6,7,8,9,10,11,10,9,8,7,6];

const BLACK_CORNER =  1125899906842624;
const WHITE_CORNER =  1099511627776;
const CENTER = 35184372088832;

var Front:int;
var Back:int;

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
