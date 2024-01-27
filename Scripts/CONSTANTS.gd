extends Node

	#Defaults
const HEX_BOARD_RADIUS = 5;
const DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;

	#Variations
const VARIATION_ONE_FEN = 'p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1';
const VARIATION_TWO_FEN = '6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1';

	#State Tests
const EMPTY_BOARD = '6/7/8/9/10/11/10/9/8/7/6 w - 1';
const BLACK_CHECK = '1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1';
const BLOCKING_TEST = '6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1';

	#Piece Tests
const PAWN_TEST = '6/7/8/9/10/5P5/10/9/8/7/6 w - 1';
const KNIGHT_TEST = '6/7/8/9/10/5N5/10/9/8/7/6 w - 1';
const BISHOP_TEST = '6/7/8/9/10/5B5/10/9/8/7/6 w - 1';
const ROOK_TEST = '6/7/8/9/10/5R5/10/9/8/7/6 w - 1';
const QUEEN_TEST = '6/7/8/9/10/5Q5/10/9/8/7/6 w - 1';
const KING_TEST = '6/7/8/9/10/5K5/10/9/8/7/6 w - 1';

