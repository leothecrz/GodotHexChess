
using System;
using System.Runtime.InteropServices;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
	class HistEntry
	{
		public Vector2I from {get; private set;}
		public Vector2I to {get; private set;}

		public bool EnPassant {get; private set;}
		public bool Check {get; private set;}
		public bool Over {get; private set;}
		public bool Promote {get; private set;}
		public bool Capture {get; private set;}
		public bool CaptureTopSneak {get; private set;}

		public int piece {get; private set;}
		public int pPiece {get; set;}
		public int pIndex {get; set;}
		public int cPiece {get; set;}
		public int cIndex {get; set;}

		public HistEntry(int PIECE, Vector2I FROM, Vector2I TO)
		{
			piece = PIECE;
			from = new Vector2I(FROM.X,FROM.Y);
			to = new Vector2I(TO.X,TO.Y);
			
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
		public string SimpleString()
		{	
			PIECES tempPiece = (piece > 0b1000) ? (PIECES)(piece - 0b1000) : (PIECES)(piece);

			char dispSym = tempPiece switch {
				PIECES.PAWN => 'p',
				PIECES.KNIGHT => 'n',
				PIECES.ROOK => 'r',
				PIECES.BISHOP => 'b',
				PIECES.QUEEN => 'q',
				PIECES.KING => 'k',
				_ => 'e'};
			
			if (piece > 0b1000) dispSym -= ' ';
			return $"{dispSym} - {EncodeFEN(from.X,from.Y),3:t}:{EncodeFEN(to.X,to.Y),3:t}";
		} 

		public string FullString()
		{
			return $"P:{piece}, from:({from.X},{from.Y}), to:({to.X},{to.Y}) -- e:{EnPassant} c:{Check} o:{Over} -- p:{Promote} type:{pPiece} index:{pIndex} -- cap:{Capture} top:{CaptureTopSneak} type:{cPiece} index:{cIndex}";
		}

		public override string ToString()
		{
			return $"P:{piece}, from:({from.X},{from.Y}), to:({to.X},{to.Y}) -- e:{EnPassant} c:{Check} o:{Over} -- p:{Promote} type:{pPiece} -- cap:{Capture} top:{CaptureTopSneak} type:{cPiece}";
		}
	}
}