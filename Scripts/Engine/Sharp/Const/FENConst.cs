
namespace HexChess
{
	public class FENConst
	{
		public const string DEFAULT_FEN_STRING = "6/p5P/rp4PR/n1p3P1N/q2p2P2Q/bbb1p1P1BBB/k2p2P2K/n1p3P1N/rp4PR/p5P/6 w - 1" ;

		//	AttackBoardTest
		public const string ATTACK_BOARD_TEST = "6/7/8/9/k9/10Q/9K/9/8/7/6 w - 1";
		public const string ATTACKING_BOARD_TEST = "p5/7/8/9/10/k9K/10/9/8/7/5P w - 1";

		//	Variations
		public const string VARIATION_ONE_FEN = "p4P/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/p4P w - 1";
		public const string VARIATION_TWO_FEN = "6/rp3PR/bp4PN/np5PB/bp6PQ/kp7PK/qp6PB/pb5PN/np4BP/rp3PR/6 w - 1";

		//	State Tests
		public const string EMPTY_BOARD   = "6/7/8/9/10/11/10/9/8/7/6 w - 1";
		public const string BLACK_CHECK   = "1P4/1k4K/8/9/10/11/10/9/8/7/6 w - 1";
		public const string BLOCKING_TEST = "6/7/8/9/10/kr7NK/10/9/8/7/6 w - 1";
		public const string UNDO_TEST_ONE   = "6/7/8/9/10/4p6/k2p2P2K/9/8/7/6 w - 1";
		public const string UNDO_TEST_TWO   = "6/7/8/9/1P7/11/3p2P2K/9/8/7/k5 w - 1";
		public const string UNDO_TEST_THREE   = "6/7/8/9/2R6/11/k2p2P2K/9/8/7/6 w - 1";
		public const string KING_INTERACTION_TEST = "5P/7/8/9/10/k9K/10/9/8/7/p5 w - 1";
		public const string ILLEGAL_ENPASSANT_TEST_ONE = "6/7/8/4K3/5P4/4p6/6r3/9/8/7/k5 w - 1";

		//	Piece Tests
		public const string PAWN_TEST   = "6/7/8/9/10/5P5/10/9/8/7/6 w - 1";
		public const string KNIGHT_TEST = "6/7/8/9/10/5N5/10/9/8/7/6 w - 1";
		public const string BISHOP_TEST = "6/7/8/9/10/5B5/10/9/8/7/6 w - 1";
		public const string ROOK_TEST   = "6/7/8/9/10/5R5/10/9/8/7/6 w - 1";
		public const string QUEEN_TEST  = "6/7/8/9/10/5Q5/10/9/8/7/6 w - 1";
		public const string KING_TEST   = "6/7/8/9/10/5K5/10/9/8/7/6 w - 1";

		//	CheckMate Test:
		public const string CHECK_TEST_ONE   = "q6/7/8/9/10/k8K1/10/9/8/7/q5 w - 20";
		public const string CHECK_TEST_TWO   = "6/7/8/9/10/11/10/9/8/7/6 w - 1";

		public const string EXPOSE_TEST_FEN_STRING = "6/7/1p4P1/9/q2p2P2Q/4p1P4/k2p2P2K/9/1p4P1/7/6 w - 1" ;

		public const string INDEX_TEST   = "3K2/7/8/9/10/5R5/10/9/8/7/2k3 w - 1";

	}
}