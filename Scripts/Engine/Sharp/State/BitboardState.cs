using System;
using System.Collections.Generic;
using System.Numerics;

using Godot;

using static HexChess.HexConst;

namespace HexChess
{

public class BitboardState
{

	public Bitboard128[] WHITE_BB {get; private set;}
	public Bitboard128[] BLACK_BB {get; private set;}
	public Bitboard128 BIT_WHITE {get; private set;}
	public Bitboard128 BIT_BLACK {get; private set;}
	public Bitboard128 BIT_ALL {get; private set;}


	public BitboardState()
	{
		initiateStateBitboards();
	}

	//
	public void initiateStateBitboards()
	{
		int size = Enum.GetValues(typeof(PIECES)).Length - 1;
		WHITE_BB = new Bitboard128[size];
		BLACK_BB = new Bitboard128[size];
		for(int i=0; i<size; i+=1)
		{
			WHITE_BB[i] = new Bitboard128(0,0);
			BLACK_BB[i] = new Bitboard128(0,0);
		}
		generateCombinedStateBitboards();
	}
	//
	public void clearCombinedStateBitboards()
	{
		BIT_ALL = null;
		BIT_BLACK = null;
		BIT_WHITE = null;
	}
	//
	public void clearStateBitboard()
	{
		for (int i=0 ; i < WHITE_BB.Length; i+=1)
		{
			WHITE_BB[i] = null;
			BLACK_BB[i] = null;
		}
		
	}
	//
	public void generateCombinedStateBitboards()
	{
		BIT_WHITE = Bitboard128.ORCombine(WHITE_BB);
		BIT_BLACK = Bitboard128.ORCombine(BLACK_BB);
		BIT_ALL = BIT_WHITE.OR(BIT_BLACK);
	}


	// Bitboard Checks

	// Checks BIT_ALL for the existence of a piece at index
	public bool IsIndexEmpty(int index)
	{
		Bitboard128 temp = Bitboard128.OneBitAt(index);
		Bitboard128 result = BIT_ALL.AND(temp);
		bool status = result.Empty();
		result = null;
		temp = null;
		return status;
	}
	// Assumes Piece Exists. Check on which side bitboard the piece exist on.
	public bool IsPieceWhite(int index)
	{
		Bitboard128 check = Bitboard128.OneBitAt(index);
		Bitboard128 result = BIT_WHITE.AND(check);
		bool status = result.Empty();
		result = null;
		check = null;
		return !status;
	}
	// Assumes Piece Exists. Check on which type bitboard the piece exist on. Checks Opponent bitboard.
	public PIECES PieceTypeOf(int index, bool isWhiteTrn)
	{
		int i = 0;
		Bitboard128 temp = Bitboard128.OneBitAt(index);
		Bitboard128[] opponentBitBoards;
		if(isWhiteTrn)
			opponentBitBoards = BLACK_BB;
		else
			opponentBitBoards = WHITE_BB;

		foreach (Bitboard128 bb in opponentBitBoards)
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
		int type = (int)HexConst.PieceTypeOf(piece);

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
		ClearIndexOf(index, isWhite, PieceTypeOf(index, !isWhite));
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