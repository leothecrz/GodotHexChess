extends Node
class_name GDHexConst;

const SQRT_THREE_DIV_TWO = sqrt(3) / 2;
enum PIECES { ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING };
enum SIDES { BLACK, WHITE };
enum MOVE_TYPES { MOVES, CAPTURE, ENPASSANT, PROMOTE}

const PIXEL_OFFSET : int = 35;
const AXIAL_X_SCALE : float = 1.4;
const AXIAL_Y_SCALE : float = 0.9395;
const PIECE_SCALE : float = 0.175;
const MOVE_SCALE : float = 0.015;

static func axialToPixel(axial : Vector2i) -> Vector2:
	var x = float(axial.x) * GDHexConst.AXIAL_X_SCALE;
	var y = (GDHexConst.SQRT_THREE_DIV_TWO * ( float(axial.y * 2) + float(axial.x) ) ) * GDHexConst.AXIAL_Y_SCALE;
	return Vector2(x, y);

static func getTimeUtil() -> float:
	return Time.get_ticks_usec()/1000000.0;

static func getSCord(cords : Vector2i) -> int:
	return -cords.x-cords.y;

static func getAxialDistance(from : Vector2i, to : Vector2i) -> int:
	return maxi(maxi(
			abs( from.x-to.x ),
			abs( from.y-to.y ) ), 
			abs( getSCord(from)-getSCord(to) ) );
 
