
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
	class HistEntry
	{
		private Vector2I from;
		private Vector2I to;

		private bool enPassant;
		private bool check;
		private bool over;
		private bool promote;
		private bool capture;
		private bool captureTopSneak;

		private int piece;
		private int pPiece;
		private int pIndex;
		private int cPiece;
		private int cIndex;

		public HistEntry(int PIECE, Vector2I FROM, Vector2I TO)
		{
			piece = PIECE;
			from = new Vector2I(FROM.X,FROM.Y);
			to = new Vector2I(TO.X,TO.Y);
			
			promote = false;
			enPassant = false;
			check = false;
			over = false;
			capture = false;
			captureTopSneak = false;
			return;
		}

		public void _flipPromote()
		{
			promote = !promote;
		}
		public bool _getPromote()
		{
			return promote;
		}
		public void _flipEnPassant()
		{
			enPassant = !enPassant;
		}
		public bool _getEnPassant()
		{
			return enPassant;
		}
		public void _flipCheck()
		{
			check = !check;
		}
		public bool _getCheck()
		{
			return check;
		}
		public void _flipOver()
		{ 
			over = !over;
		}
		public bool _getOver()
		{
			return over;
		}
		public void _flipCapture()
		{
			capture = !capture;
		}
		public bool _getCapture()
		{
			return capture;
		}
		public bool _getIsCaptureTopSneak()
		{
			return captureTopSneak;
		}
		public void _flipTopSneak()
		{
			captureTopSneak = !captureTopSneak;
		}
		public int _getCPieceType()
		{
			return cPiece;
		}
		public void _setCPieceType ( int type ){
			cPiece = type;
		}
		public int _getCIndex (){
			return cIndex;
		}
		public void _setCIndex ( int i )
		{
			cIndex = i;
		}
		public int _getPPieceType(){
			return pPiece;
		}
		public void _setPPieceType ( int type )
		{
			pPiece = type;
		}
		public int _getPIndex (){
			return pIndex;
		}
		public void _setPIndex ( int i ){
			pIndex = i;
		}
		public int _getPiece(){
			return piece;
		}
		public Vector2I _getFrom(){
			return from;
		}
		public Vector2I _getTo(){
			return to;
		}
		public string simpleString()
		{
			return $"{piece} {encodeEnPassantFEN(from.X,from.Y)} {encodeEnPassantFEN(to.X,to.Y)}";
		} 
		public override string ToString()
		{
			return $"P:{piece}, from:({from.X},{from.Y}), to:({to.X},{to.Y}) -- e:{enPassant} c:{check} o:{over} -- p:{promote} type:{pPiece} index:{pIndex} -- cap:{capture} top:{captureTopSneak} type:{cPiece} index:{cIndex}";
		}
	}
}