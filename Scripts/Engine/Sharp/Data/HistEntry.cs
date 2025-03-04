
using System;
using System.Runtime.InteropServices;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
	class HistEntry
	{
		public Vector2I From {get; private set;}
		public Vector2I To {get; set;}

		public bool EnPassant {get; private set;}
		public bool Check {get; private set;}
		public bool Over {get; private set;}
		public bool Promote {get; private set;}
		public bool Capture {get; private set;}
		public bool CaptureTopSneak {get; private set;} // pawn enpasssant capture

		public int Piece {get; private set;}
		public PIECES ProPiece {get; set;}
		public int ProIndex {get; set;} // index of promoted piece in Active Pieces list.
		public PIECES CapPiece {get; set;}
		public int CapIndex {get; set;} // index of captured piece in Active Pieces list.

		public HistEntry(int PIECE, Vector2I FROM, Vector2I TO)
		{
			Piece = PIECE;
			From = new Vector2I(FROM.X,FROM.Y);
			To = new Vector2I(TO.X,TO.Y);
			
			Promote = false;
			EnPassant = false;
			Check = false;
			Over = false;
			Capture = false;
			CaptureTopSneak = false;
			return;
		}
		public bool FlipPromote()
		{
			Promote = !Promote;
			return Promote;
		}
		public bool FlipEnPassant()
		{
			EnPassant = !EnPassant;
			return EnPassant;
		}
		public bool FlipCheck()
		{
			Check = !Check;
			return Check;
		}
		public bool FlipOver()
		{ 
			Over = !Over;
			return Over;
		}
		public bool FlipCapture()
		{
			Capture = !Capture;
			return Capture;
		}
		public bool FlipTopSneak()
		{
			CaptureTopSneak = !CaptureTopSneak;
			return CaptureTopSneak;
		}

		/// <summary> Returns a simplified string that represents the bitboard. </summary>
		/// <returns> A simplified string.  </returns>
		public string SimpleString()
		{	
			PIECES tempPiece = (Piece > 0b1000) ? (PIECES)(Piece - 0b1000) : (PIECES)(Piece);

			char dispSym = tempPiece switch {
				PIECES.PAWN => 'p',
				PIECES.KNIGHT => 'n',
				PIECES.ROOK => 'r',
				PIECES.BISHOP => 'b',
				PIECES.QUEEN => 'q',
				PIECES.KING => 'k',
				_ => 'e'};
			
			if (Piece > 0b1000) dispSym -= ' ';
			return $"{dispSym} - {EncodeFEN(From.X,From.Y),3:t}:{EncodeFEN(To.X,To.Y),3:t}";
		} 

		public string FullString()
		{
			return $"P:{Piece}, from:({From.X},{From.Y}), to:({To.X},{To.Y}) -- e:{EnPassant} c:{Check} o:{Over} -- p:{Promote} type:{ProPiece} index:{ProIndex} -- cap:{Capture} top:{CaptureTopSneak} type:{CapPiece} index:{CapIndex}";
		}

		public override string ToString()
		{
			return $"P:{Piece} - {HexConst.MaskPieceTypeFrom(Piece)}, from:({From.X},{From.Y}), to:({To.X},{To.Y}) -- e:{EnPassant} c:{Check} o:{Over} -- p:{Promote} type:{ProPiece} -- cap:{Capture} top:{CaptureTopSneak} type:{CapPiece}";
		}
	}
}