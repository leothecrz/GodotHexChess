using System;
using System.Collections.Generic;
using System.Numerics;

using Godot;

using static HexChess.HexConst;

namespace HexChess
{

public class BitboardState
{
	/// <summary> All bitboards for WHITE side. Use [piecetype] to get the type's bitboard. </summary>
	public Bitboard128[] WHITE_BB {get; private set;}
	/// <summary> All bitboards for BLACK side. Use [piecetype] to get the type's bitboard. </summary>
	public Bitboard128[] BLACK_BB {get; private set;}
	/// <summary> Combined State of WHITE_BB </summary>
	public Bitboard128 BIT_WHITE {get; private set;}
	/// <summary> Combined State of BLACK_BB </summary>
	public Bitboard128 BIT_BLACK {get; private set;}
	/// <summary> Combined State of WHITE_BB and BLACK_BB </summary>
	public Bitboard128 BIT_ALL {get; private set;}


	/// <summary> Constructor. Initiates the state bitboards with the using the default PIECES. </summary>
	public BitboardState()
	{
		InitiateStateBitboards();
	}

	/// <summary> Combines all same color pieces into BIT_WHITE and BIT_BLACK. Combines those to create BIT_ALL. </summary>
	public void GenerateCombinedStateBitboards()
	{
		BIT_WHITE = Bitboard128.ORCombine(WHITE_BB);
		BIT_BLACK = Bitboard128.ORCombine(BLACK_BB);
		BIT_ALL = BIT_WHITE.OR(BIT_BLACK);
	}

	/// <summary> Create a bitboard128 for every piece type. Also creates the combined bitboard states. </summary>
	public void InitiateStateBitboards()
	{
		InitiateStateBitboardsCustom(Enum.GetValues(typeof(PIECES)).Length - 1);
	}
	/// <summary>
	/// Given a custom piece type count:
	/// Create a bitboard128 for every piece type. Also creates the combined bitboard states.
	/// </summary>
	/// <param name="piecesCount"> Piece Type Count. Will create a bitboard for each piece type </param>
	public void InitiateStateBitboardsCustom(int piecesCount)
	{
		int size = piecesCount;
		WHITE_BB = new Bitboard128[size];
		BLACK_BB = new Bitboard128[size];
		for(int i=0; i<size; i+=1)
		{
			WHITE_BB[i] = new Bitboard128(0,0);
			BLACK_BB[i] = new Bitboard128(0,0);
		}
		GenerateCombinedStateBitboards();
	}
	
	/// <summary> Clear the ALL, WHITE, and BLACK combined states. </summary>
	public void ClearCombinedStateBitboards()
	{
		BIT_ALL = null;
		BIT_BLACK = null;
		BIT_WHITE = null;
	}
	/// <summary> Clear all of the bitboards in WHITE_BB[] and BLACK_BB[] </summary>
	public void ClearStateBitboards()
	{
		for (int i=0 ; i < WHITE_BB.Length; i+=1)
		{
			WHITE_BB[i] = null;
			BLACK_BB[i] = null;
		}
	}
	

	// Bitboard Checks


	/// <summary> Checks index of BIT_ALL if a piece is there. </summary>
	/// <param name="index"> 0 less-than-or-equal index less-than-or-equal 127. Index To check </param>
	/// <returns> True - if index is empty. False - if not empty. </returns>
	public bool IsIndexEmpty(int index)
	{
		return BIT_ALL.AND(Bitboard128.OneBitAt(index)).Empty();
	}
	/// <summary> Assumes Piece Exists. Check on which SIDE bitboard the piece exist on. </summary>
	/// <param name="index"> 0 less-than-or-equal index less-than-or-equal 127. Index To check </param>
	/// <returns></returns>
	public bool IsPieceWhite(int index)
	{
		return !BIT_WHITE.AND(Bitboard128.OneBitAt(index)).Empty();
	}
	/// <summary> Assumes Piece Exists. Check on which SIDE bitboard the piece exist on. </summary>
	/// <param name="index"> 0 less-than-or-equal index less-than-or-equal 127. Index To check </param>
	/// <returns></returns>
	public bool IsPieceBlack(int index)
	{
		return !IsPieceWhite(index);
	}
	
	/// <summary> Assumes Piece Exists. Check on which type bitboard the piece exist on. Checks Opponent bitboard. </summary>
	/// <param name="index"> </param>
	/// <param name="isWhiteTrn"> </param>
	/// <returns></returns>
	public PIECES GetPieceTypeFrom(int index, bool isWhiteTrn)
	{
		int i = 0;
		Bitboard128 temp = Bitboard128.OneBitAt(index);
		Bitboard128[] selfBitBoards = isWhiteTrn ? WHITE_BB : BLACK_BB;

		foreach (Bitboard128 bb in selfBitBoards)
		{
			i += 1;
			Bitboard128 result = temp.AND(bb);
			var status = result.Empty();
			result = null;
			if (!status) break;
		}
		
		temp = null;
		return (PIECES) i;
	}
	// Use the board to find the location of all pieces. 
	// Intended to be ran only once at the begining.
	public Dictionary<PIECES,List<Vector2I>>[] bbfindPieces()
	{
		Dictionary<PIECES,List<Vector2I>>[] pieceCords = new Dictionary<PIECES,List<Vector2I>>[] 
		{
			new Dictionary<PIECES, List<Vector2I>>()
			{ 
				{PIECES.PAWN, new List<Vector2I> {}},
				{PIECES.KNIGHT, new List<Vector2I> {}},
				{PIECES.ROOK, new List<Vector2I> {}},
				{PIECES.BISHOP, new List<Vector2I> {}},
				{PIECES.QUEEN, new List<Vector2I> {}},
				{PIECES.KING, new List<Vector2I> {}} 
			},
			new Dictionary<PIECES, List<Vector2I>>()
			{ 
				{PIECES.PAWN, new List<Vector2I> {}},
				{PIECES.KNIGHT, new List<Vector2I> {}},
				{PIECES.ROOK, new List<Vector2I> {}},
				{PIECES.BISHOP, new List<Vector2I> {}},
				{PIECES.QUEEN, new List<Vector2I> {}},
				{PIECES.KING, new List<Vector2I> {}} 
			}
		};
		
		int type = 0;
		foreach( Bitboard128 bb in BLACK_BB )
		{
			type += 1;
			List<int> pieceIndexes = bb.ExtractIndexes();
			foreach(int i in pieceIndexes)
				pieceCords[(int)SIDES.BLACK][(PIECES)type].Add(IndexToQR(i));
		}
		type = 0;
		foreach( Bitboard128 bb in WHITE_BB)
		{
		 	type += 1;
		 	List<int> pieceIndexes = bb.ExtractIndexes();
		 	foreach(int i in pieceIndexes)
		 		pieceCords[(int)SIDES.WHITE][(PIECES)type].Add(IndexToQR(i));
		}

		return pieceCords;
	}


	//ADD


	// Update the selected sides type bitboard at (q,r)
	public void add_IPieceToBitBoardsOf(int q, int r, int piece, bool updateWhite)
	{
		int index = QRToIndex(q,r);
		Bitboard128 insert = Bitboard128.OneBitAt(index);
		int type = (int)HexConst.MaskPieceTypeFrom(piece);

		if(updateWhite)
		{
			Bitboard128 temp = WHITE_BB[type-1].OR(insert);
			WHITE_BB[type-1] = null;
			WHITE_BB[type-1] = temp;
		}
		else
		{
			Bitboard128 temp = BLACK_BB[type-1].OR(insert);
			BLACK_BB[type-1] = null;
			BLACK_BB[type-1] = temp;
		}
		
		insert = null;
		return;
	}
	// Update the bitboard at (q,r) using piece int
	public void add_IPieceToBitBoards(int q, int r, int piece)
	{
		add_IPieceToBitBoardsOf(q, r, piece, isPieceWhite(piece));
		return;
	}
	// Update the bitboard based on piece FEN STRING
	public void addS_PieceToBitBoards(int q, int r, char c)
	{
		bool isBlack = true;
		if(c < 'a')
		{
			isBlack = false;
			c = (char) ( c + 32 );
		}
		PIECES piece = PIECES.ZERO;
		switch(c)
		{
			case 'p': piece = PIECES.PAWN; break;
			case 'n': piece = PIECES.KNIGHT; break;
			case 'r': piece = PIECES.ROOK; break;
			case 'b': piece = PIECES.BISHOP; break;
			case 'q': piece = PIECES.QUEEN; break;
			case 'k': piece = PIECES.KING; break;
		}
		add_IPieceToBitBoards(q,r, ToPieceInt(piece, isBlack));
		return;
	}
	
	public void AddPieceOf(int index, bool isWhite, PIECES type)
	{
		Bitboard128[] activeBoard;
		if(isWhite)
			activeBoard = WHITE_BB;
		else
			activeBoard = BLACK_BB;
		var pos = (int) type - 1;
		var mask = Bitboard128.OneBitAt(index);
		var result = activeBoard[pos].OR(mask);
		mask = null;
		activeBoard[pos] = null;
		activeBoard[pos] = result;
		return;
	}
	

	//Clear
	

	// Assumes Piece Exists. Clears index of selected side.
	public void ClearIndexFrom(int index, bool isWhite)
	{
		ClearIndexOf(index, isWhite, GetPieceTypeFrom(index, isWhite));
		return;
	}
	// Assumes Piece Exists. Clears index of selected side from selected type.
	public void ClearIndexOf(int index, bool isWhite, PIECES type)
	{
		Bitboard128[] activeBoard;
		if(isWhite) activeBoard = WHITE_BB; else activeBoard = BLACK_BB;
		Bitboard128 mask = Bitboard128.OneBitAt(index);
		mask = mask.FLIP();
		int pos = (int) type - 1;
		var result = activeBoard[pos].AND(mask);
		mask = null;
		activeBoard[pos] = null;
		activeBoard[pos] = result;
		return;
	}

}

}