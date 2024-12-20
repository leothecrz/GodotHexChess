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
		BIT_BLACK = null;
		BIT_WHITE = null;
		BIT_ALL = null;
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
	/// <returns> - True : piece at index is white. - False : piece at index is black. </returns>
	public bool IsPieceWhite(int index)
	{
		return !BIT_WHITE.AND(Bitboard128.OneBitAt(index)).Empty();
	}
	/// <summary> Assumes Piece Exists. Check on which SIDE bitboard the piece exist on. </summary>
	/// <param name="index"> 0 less-than-or-equal index less-than-or-equal 127. Index To check </param>
	/// <returns> - True : piece at index is black. - False : piece at index is white.</returns>
	public bool IsPieceBlack(int index)
	{
		return !IsPieceWhite(index);
	}
	
	/// <summary> Assumes Piece Exists. Check on which type bitboard the piece exist on. </summary>
	/// <param name="index"> Index to check </param>
	/// <param name="fromWhite"> If true checks WHITE_BB else BLACK_BB </param>
	/// <returns></returns>
	public PIECES GetPieceTypeFrom(int index, bool fromWhite)
	{
		Bitboard128 temp = Bitboard128.OneBitAt(index);
		Bitboard128[] selfBitBoards = fromWhite ? WHITE_BB : BLACK_BB;
		for(int i = 0; i< selfBitBoards.Length; i+=1)
		{
			if(temp.AND(selfBitBoards[i]).Empty())
				continue;
			return (PIECES) (i+1);
		}
		return PIECES.ZERO;
	}
	
	private static void ExtractSidesPieces(Bitboard128[] bitboards, Dictionary<PIECES, List<Vector2I>> pieceDict)
	{
		for (int type = 0; type < bitboards.Length; type++)
    	{
			var pieceIndexes = bitboards[type].ExtractIndexes();
			var pieceType = (PIECES)(type + 1);

			foreach (int index in pieceIndexes)
			{
				pieceDict[pieceType].Add(IndexToQR(index));
			}
    	}
	}
	/// <summary>
	/// This method retrieves the positions of different chess pieces for both sides (black and white) on the board.
	/// It analyzes the bitboards for each side, extracts piece positions, and organizes them in dictionaries.
	/// </summary>
	/// <returns>
	/// An array of dictionaries containing the coordinates of chess pieces for both sides:
	/// - Index 0: Black pieces.
	/// - Index 1: White pieces.
	/// Each dictionary maps piece types (<see cref="PIECES"/>) to a list of their respective positions (<see cref="Vector2I"/>).
	/// </returns>
	public Dictionary<PIECES,List<Vector2I>>[] ExtractPieceList()
	{
		Dictionary<PIECES,List<Vector2I>>[] pieceCords = new Dictionary<PIECES,List<Vector2I>>[] 
		{
			InitPiecesDict(), 
			InitPiecesDict()
		};
		ExtractSidesPieces(BLACK_BB, pieceCords[(int)SIDES.BLACK]);
		ExtractSidesPieces(WHITE_BB, pieceCords[(int)SIDES.WHITE]);
		return pieceCords;
	}


	//ADD


	/// <summary> Update the piece bitboard at (q,r) for the specified side. </summary>
	/// <param name="piece"> int representation of piece (type needed) </param>
	/// <param name="q"> Vector2I X </param>
	/// <param name="r"> Vector2I Y </param>
	/// <param name="updateWhite"> Select which side to update </param>
	public void AddFromIntTo(PIECES piece, int q, int r, bool updateWhite)
	{
		int index = QRToIndex(q,r);
		int typeIndex = (int) piece - 1;
		Bitboard128[] SELF_BB = updateWhite ? WHITE_BB : BLACK_BB; 
		Bitboard128 insert = Bitboard128.OneBitAt(index);
		SELF_BB[typeIndex] = SELF_BB[typeIndex].OR(insert);
		return;
	}
	/// <summary> Update the piece bitboard at (q,r). </summary>
	/// <param name="piece"> int representation of piece (side and type) </param>
	/// <param name="q"> Vector2I X </param>
	/// <param name="r"> Vector2I Y </param>
	public void AddFromIntTo(int piece, int q, int r)
	{
		AddFromIntTo(MaskPieceTypeFrom(piece), q, r, isPieceWhite(piece));
		return;
	}
	/// <summary> Update the piece bitboard at (q,r). Using a char </summary>
	/// <param name="c"> char representing piece in set {P,N,R,B,Q,K,p,n,r,b,q,k}. Uppercase updates W. Lowercase updates B. </param>
	/// <param name="q"> Vector2I X </param>
	/// <param name="r"> Vector2I Y </param>
	public void AddFromCharTo(char c, int q, int r)
	{
		bool isBlack = true;
		if(c < 'a')
		{
			isBlack = false;
			c = (char) ( c + 32 ); //to lower
		}
		PIECES piece = c switch
		{
			'p' => PIECES.PAWN,
			'n' => PIECES.KNIGHT,
			'r' => PIECES.ROOK,
			'b' => PIECES.BISHOP,
			'q' => PIECES.QUEEN,
			'k' => PIECES.KING,
			_ => PIECES.ZERO
		};
		AddFromIntTo(piece, q,r, !isBlack);
		return;
	}
	/// <summary>
	/// 
	/// </summary>
	/// <param name="index"></param>
	/// <param name="isWhite"></param>
	/// <param name="type"></param>
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
	

	/// <summary>
	/// Clears the bit at index from the selected side. Will search for type.
	/// </summary>
	/// <param name="index"> bit index to flip off </param>
	/// <param name="updateWhite"> side to update </param>
	/// <param name="type"> type to update </param>
	public void ClearIndexFrom(int index, bool isWhite)
	{
		ClearIndexOf(index, isWhite, GetPieceTypeFrom(index, isWhite));
		return;
	}

	/// <summary>
	/// Clears the bit at index from the selected side and from the selected type.
	/// </summary>
	/// <param name="index"> bit index to flip off </param>
	/// <param name="updateWhite"> side to update </param>
	/// <param name="type"> type to update </param>
	public void ClearIndexOf(int index, bool updateWhite, PIECES type)
	{
		int typeIndex = (int) type - 1;
		Bitboard128[] activeBoard = updateWhite ? WHITE_BB : BLACK_BB;
		Bitboard128 mask = Bitboard128.OneBitAt(index).FLIP();
		activeBoard[typeIndex] = activeBoard[typeIndex].AND(mask);
		return;
	}

}

}