using Godot;

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

using HexChess;
using static HexChess.HexConst;

[GlobalClass]
public partial class HexEngineSharp : Node
{
	// States
	private BoardState HexState;		
	private BitboardState BitBoards;
	private EnemyState Enemy;


	//ATK
	private Dictionary<int, Dictionary<int,int>> WhiteAttackBoard;
	private Dictionary<int, Dictionary<int,int>> BlackAttackBoard;
	
	// Pieces
	private Dictionary<Vector2I, List<Vector2I>> influencedPieces = null;
	private Dictionary<Vector2I, List<Vector2I>> lastInfluencedPieces = null;
	private Dictionary<Vector2I, List<Vector2I>> blockingPieces = null;
	private Dictionary<PIECES, List<Vector2I>>[] activePieces = null;

	// Moves
	private Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves = null;

	// Check & Mate
	private List<Vector2I> GameInCheckMoves;

	// UndoFlags and Data
	private bool uncaptureValid  = false;
	private bool unpromoteValid  = false;
	private PIECES unpromoteType  = PIECES.ZERO;
	private int unpromoteIndex   = -1;
	private PIECES undoType = PIECES.ZERO;
	private int undoIndex = -1;
	private Vector2I undoTo;

	//Move Auth
	private bool bypassMoveLock = false;

	// History
	private Stack<HistEntry> historyStack;

	//Testing
	public ulong startTime;
	public ulong stopTime;


	public HexEngineSharp()
	{
		HexState = new BoardState();
		BitBoards = new BitboardState();
		Enemy = new EnemyState();
	}


	// Turn Modification

	
	
	public void resetTurnFlags()
	{
		HexState.isCheck = false;
		HexState.captureValid = false;
		HexState.EnPassantCordsValid = false;
		return;
	}


	// Board Search

	private List<Vector2I> bbsearchForPawnsAtk(Vector2I pos, bool isWTurn)
	{
		int leftCaptureR = isWTurn ? 0 :  1;
		int rightCaptureR = isWTurn ? -1 : 0;
		int qpos = pos.X - 1;
		var lst = new List<Vector2I> {};

		if( Bitboard128.inBitboardRange(qpos, leftCaptureR) )
		{
			int index = QRToIndex(qpos, leftCaptureR);
			if( (!BitBoards.IsIndexEmpty(index)) && 
				(BitBoards.IsPieceWhite(index) != isWTurn) )
				if(BitBoards.PieceTypeOf(index, isWTurn) == PIECES.PAWN)
					lst.Add(new Vector2I(qpos, leftCaptureR));
		}
		qpos = pos.X + 1;
		if( Bitboard128.inBitboardRange(qpos, rightCaptureR) )
		{
			int index = QRToIndex(qpos, rightCaptureR);
			if( (!BitBoards.IsIndexEmpty(index)) &&
			 (BitBoards.IsPieceWhite(index) != isWTurn) )
				if(BitBoards.PieceTypeOf(index, isWTurn) == PIECES.PAWN)
					lst.Add(new Vector2I(qpos, rightCaptureR));
		}
		return lst;
	}
	private List<Vector2I> bbsearchForKnightsAtk(Vector2I pos, bool isWTurn)
	{
		var lst = new List<Vector2I> {};
		int invertAt2Counter = 0;
		foreach(int m in KNIGHT_MULTIPLERS)
			foreach( Vector2I activeVector in KNIGHT_VECTORS.Values)
			{
				int checkingQ = pos.X + (((invertAt2Counter < 2) ? activeVector.X : activeVector.Y) * m);
				int checkingR = pos.Y + (((invertAt2Counter < 2) ? activeVector.Y : activeVector.X) * m);
				if (Bitboard128.inBitboardRange(checkingQ,checkingR))
				{
					int index = QRToIndex(checkingQ, checkingR);
					if( ! BitBoards.IsIndexEmpty(index) && (BitBoards.IsPieceWhite(index) != isWTurn) )
						if(BitBoards.PieceTypeOf(index, isWTurn) == PIECES.KNIGHT)
							lst.Add(new Vector2I(checkingQ, checkingR));
				}
			}
		return lst;
	}
	private List<Vector2I> bbsearchForSlidingAtk(Vector2I pos, bool isWTurn, bool checkForQueens, PIECES initPiece, Dictionary<string,Vector2I> VECTORS)
	{
		var lst = new List<Vector2I> {};
		var checkFor = new List<PIECES> {initPiece};
		if(checkForQueens)
			checkFor.Add(PIECES.QUEEN);
		
		foreach(Vector2I activeVector in VECTORS.Values)
		{
			int checkingQ = pos.X + activeVector.X;
			int checkingR = pos.Y + activeVector.Y;
			while ( Bitboard128.inBitboardRange(checkingQ, checkingR) )
			{
				int index = QRToIndex(checkingQ, checkingR);
				if (BitBoards.IsIndexEmpty(index)){}
				else if (BitBoards.IsPieceWhite(index) != isWTurn)
				{
					if ( checkFor.Contains( BitBoards.PieceTypeOf(index, isWTurn)))
						lst.Add(new Vector2I(checkingQ, checkingR));
					break;
				}
				else
					break;
				checkingQ += activeVector.X;
				checkingR += activeVector.Y;
			}
		}
		return lst;
	}
	private List<Vector2I> bbsearchForMyAttackers(Vector2I from, bool isWhiteTrn)
	{
		int side = (int)( isWhiteTrn ? SIDES.BLACK : SIDES.WHITE);
		bool hasQueens = activePieces[side][PIECES.QUEEN].Count > 0;
		var attackers = new List<Vector2I> {};

		if (activePieces[side][PIECES.PAWN].Count > 0)
			attackers.AddRange(bbsearchForPawnsAtk(from, isWhiteTrn));
		if (activePieces[side][PIECES.KNIGHT].Count > 0)
			attackers.AddRange(bbsearchForKnightsAtk(from, isWhiteTrn));
		if (activePieces[side][PIECES.ROOK].Count > 0 || hasQueens)
			attackers.AddRange(bbsearchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.ROOK, ROOK_VECTORS));
		if (activePieces[side][PIECES.BISHOP].Count > 0 || hasQueens)
			attackers.AddRange(bbsearchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.BISHOP, BISHOP_VECTORS));
		return attackers;
	}


	// Attack Board


	private Dictionary<int,Dictionary<int,int>> createAttackBoard(int radius)
	{
		var rDictionary = new Dictionary<int,Dictionary<int,int>>(2*radius);
		for( int q=-radius; q <= radius; q +=1 )
		{
			int negQ = q * -1;
			int minRow = Math.Max(-radius, (negQ-radius));
			int maxRow = Math.Min(radius, (negQ+radius));
			rDictionary.Add(q, new Dictionary<int, int>(maxRow-minRow));
			for(int r = minRow; r<= maxRow; r += 1 )
				rDictionary[q].Add(r, 0);
		}
		return rDictionary;
	}
	// Based on the turn determine the appropriate board to update.
	private void updateAttackBoard(int q, int r, int mod)
	{
		if(HexState.isWhiteTurn)
			WhiteAttackBoard[q][r] += mod;
		else
			BlackAttackBoard[q][r] += mod;
		return;
	}
	// Based on the turn determine the appropriate board to update.
	private void updateOpposingAttackBoard(int q, int r, int mod)
	{
		if(!HexState.isWhiteTurn)
			WhiteAttackBoard[q][r] += mod;
		else
			BlackAttackBoard[q][r] += mod;
		return;
	}
	private void removePawnAttacks(Vector2I cords)
	{
		//FIX
		var leftCaptureR = HexState.isWhiteTurn ?  cords.Y : cords.Y + 1;
		var rightCaptureR = HexState.isWhiteTurn ? cords.Y-1 : cords.Y;
		//Left Capture
		if( Bitboard128.inBitboardRange(cords.X-1, leftCaptureR) )
			updateAttackBoard(cords.X-1, leftCaptureR, -1);
		//Right Capture
		if( Bitboard128.inBitboardRange(cords.X+1, rightCaptureR) )
			updateAttackBoard(cords.X+1, rightCaptureR, -1);
		return;
	}
	private void removeAttacksFrom(Vector2I cords, PIECES id) 
	{
		if(id == PIECES.PAWN)
		{
			removePawnAttacks(cords);
			return;
		}
				
		foreach( MOVE_TYPES moveType in legalMoves[cords].Keys)
			foreach( Vector2I move in legalMoves[cords][moveType])
				updateAttackBoard(move.X, move.Y, -1);
		
		return;
	}
	private void removeCapturedFromATBoard(PIECES pieceType, Vector2I cords)
	{
		HexState.isWhiteTurn = !HexState.isWhiteTurn;
		
		Dictionary<PIECES, List<Vector2I>>[] movedPiece = new Dictionary<PIECES, List<Vector2I>>[2];
		movedPiece[HexState.isWhiteTurn ? 1 : 0] =  new Dictionary<PIECES, List<Vector2I>> { {pieceType, new List<Vector2I> {new Vector2I(cords.X, cords.Y)}} };
		
		var savedMoves = legalMoves;
		legalMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>>{};
		bbfindLegalMovesFor(movedPiece);
		removeAttacksFrom(cords, pieceType);
		legalMoves = savedMoves;
		
		HexState.isWhiteTurn = !HexState.isWhiteTurn;
		return;
	}


	// BoardState


	// Fill The Board by translating a fen string. DOES NOT FULLY VERIFY FEN STRING -- (W I P)
	private bool fillBoardwithFEN(string fenString)
	{
		//Board Status
		BitBoards.initiateStateBitboards();
		
		string [] fenSections =  fenString.Split(' ');
		if (fenSections.Length != 4)
		{
			GD.PushError("Not Enough Fen Sections");
			return false;
		}

		string[] BoardColumns = fenSections[0].Split('/');
		if (BoardColumns.Length != 11)
		{
			GD.PushError("Not all Hexboard columns are defined");
			return false;
		}
			
		Regex regex = new Regex("(?i)([pnrbqk]|[0-9]|/)*");
		Match result = regex.Match(fenString);
		if (!result.Success)
		{
			GD.PushError("Regex fail");
			return false;
		}
		if( result.Value != fenSections[0] )
		{
			GD.PushError( $"{result.Value} {fenString} Invalid Board Description");
			return false;
		}
	
		for(int q=-HEX_BOARD_RADIUS; q <= HEX_BOARD_RADIUS; q+=1)
		{
			int mappedQ = q + HEX_BOARD_RADIUS;
			string activeRow = BoardColumns[mappedQ];
			
			int r1 = Math.Max(-HEX_BOARD_RADIUS, -q-HEX_BOARD_RADIUS);
			int r2 = Math.Min(HEX_BOARD_RADIUS, -q+HEX_BOARD_RADIUS);

			for(int i=0; i < activeRow.Length; i += 1 )
			{
				char activeChar = activeRow[i];
				if( charIsInt(activeChar) )
				{
					int pushDistance = (int) activeChar - '0';
					while ( (i+1 < activeRow.Length) && charIsInt(activeRow[i+1]))
					{
						i += 1;
						pushDistance *= 10;
						pushDistance += (int)(activeRow[i] - '0');
					}
					r1 += pushDistance;
				}
				else
				{
					if(r1 <= r2)
					{
						BitBoards.addS_PieceToBitBoards(q,r1,activeChar);
						r1 +=1 ;
					}
					else
					{
						GD.PushError("R1 Error");
						return false;
					}
				}
			}
		}
		BitBoards.generateCombinedStateBitboards();
		
		//Is White Turn
		if(fenSections[1] == "w")
			HexState.isWhiteTurn = true;
		else if (fenSections[1] == "b")
			HexState.isWhiteTurn = false;
		else
		{
			GD.PushError("Regex fail");
			return false;
		}
		//EnPassant Cords
		if(fenSections[2] != "-")
		{
			HexState.EnPassantCordsValid = true;
			HexState.EnPassantTarget = decodeEnPassantFEN(fenSections[2]);
			HexState.EnPassantCords = new Vector2I(HexState.EnPassantTarget.X, HexState.EnPassantTarget.Y + (HexState.isWhiteTurn ? -1 : 1));
		}
		else
		{
			HexState.EnPassantCords = new Vector2I(-5,-5);
			HexState.EnPassantTarget = new Vector2I(-5,-5);
			HexState.EnPassantCordsValid = false;
		}
		// Turn Number
		HexState.turnNumber = fenSections[3].ToInt();
		if(HexState.turnNumber < 1)
			HexState.turnNumber = 1;
			
		return true;
	}


	// Blocking Search


	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private void bbcheckForBlockingOnVector(PIECES piece, Dictionary<string,Vector2I> dirSet, Dictionary<Vector2I, List<Vector2I>> bp, Vector2I cords)
		{
			var index = QRToIndex(cords.X,cords.Y);
			var isWhiteTrn = BitBoards.IsPieceWhite(index);
			
			foreach( string direction in dirSet.Keys )
			{
				List<Vector2I> LegalMoves = new List<Vector2I> {};
				
				Vector2I dirBlockingPiece = new Vector2I(HEX_BOARD_RADIUS+1, HEX_BOARD_RADIUS+1);
				Vector2I activeVector = dirSet[direction];
				
				int checkingQ = cords.X + activeVector.X;
				int checkingR = cords.Y + activeVector.Y;
				
				while ( Bitboard128.inBitboardRange(checkingQ,checkingR) )
				{
					index = QRToIndex(checkingQ,checkingR);
					if( BitBoards.IsIndexEmpty(index) )
						if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
							LegalMoves.Add(new Vector2I(checkingQ,checkingR)); // Track legal moves for the blocking pieces
					else
					{
						if( BitBoards.IsPieceWhite(index) == isWhiteTrn ) // Friend Piece
							if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1) break; // Two friendly pieces in a row. No Danger
							else dirBlockingPiece = new Vector2I(checkingQ,checkingR); // First piece found

						else //Unfriendly Piece Found	
						{
							PIECES val = BitBoards.PieceTypeOf(index, isWhiteTrn);
							if ( (val == PIECES.QUEEN) || (val == piece) )
								if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
									LegalMoves.Add(new Vector2I(checkingQ,checkingR));
									bp[dirBlockingPiece] = LegalMoves; // store blocking piece moves
							break;
						}
					}

					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			return;
		}
	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private Dictionary<Vector2I, List<Vector2I>> bbcheckForBlockingPiecesFrom(Vector2I cords)
	{
		var blockingpieces = new Dictionary<Vector2I, List<Vector2I>>{};
		bbcheckForBlockingOnVector(PIECES.ROOK, ROOK_VECTORS, blockingpieces, cords);
		bbcheckForBlockingOnVector(PIECES.BISHOP, BISHOP_VECTORS, blockingpieces, cords);
		return blockingpieces;
	}
	

	// Pawn Moves

	
	private bool EnPassantLegal()
	{
		Vector2I kingCords = activePieces[(int)(HexState.isWhiteTurn ? SIDES.WHITE:SIDES.BLACK)][PIECES.KING][KING_INDEX];
		Vector2I targetPos = new Vector2I(HexState.EnPassantCords.X, HexState.EnPassantCords.Y + ( HexState.isWhiteTurn ? 1 : -1));
		
		foreach( Vector2I piece in lastInfluencedPieces[targetPos])
		{
			int index = QRToIndex(piece.X,piece.Y);
			if(BitBoards.IsPieceWhite(index) == HexState.isWhiteTurn) continue;
			PIECES type = BitBoards.PieceTypeOf(index, HexState.isWhiteTurn);
			if(type == PIECES.ROOK || type == PIECES.QUEEN)
			{
				if ( piece.X == kingCords.X ) return false;
				else if ( piece.Y == kingCords.Y ) return false;
				else if ( getSAxialCordFrom(piece) == getSAxialCordFrom(kingCords) ) return false;
			}
			if(type == PIECES.BISHOP || type == PIECES.QUEEN)
			{
				var differenceS = getSAxialCordFrom(piece) - getSAxialCordFrom(kingCords);
				if(piece.X - kingCords.X == piece.Y - kingCords.Y) return false;
				else if(piece.X - kingCords.X == differenceS ) return false;
				else if(piece.Y - kingCords.Y == differenceS ) return false;
			}
		}
		return true;
	}
	// Calculate Pawn Capture Moves
	private void bbfindCaptureMovesForPawn(Vector2I pawn, int qpos, int rpos)
	{
		if ( ! Bitboard128.inBitboardRange(qpos, rpos) ) return;
			
		Vector2I move = new Vector2I(qpos, rpos);
		int index = QRToIndex(qpos,rpos);
		
		if ( BitBoards.IsIndexEmpty(index) )
		{
			if( HexState.EnPassantCordsValid && (HexState.EnPassantCords.X == qpos) && (HexState.EnPassantCords.Y == rpos) )
				if( EnPassantLegal() )
					legalMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		}
		else
		{
			if(BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn)
			{
				if ( HexState.isWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					legalMoves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					legalMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
			}
		}
		
		updateAttackBoard(qpos, rpos, 1);
		return;
	}
	// Calculate Pawn Foward Moves
	private void bbfindFowardMovesForPawn(Vector2I pawn, int fowardR)
	{
		Vector2I move = new Vector2I(pawn.X,fowardR);
		bool boolCanGoFoward = false;
		// Foward Move
		if (Bitboard128.inBitboardRange(pawn.X, fowardR))
		{
			int index = QRToIndex(pawn.X,fowardR);
			if(BitBoards.IsIndexEmpty(index))
			{
				if ( HexState.isWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					legalMoves[pawn][MOVE_TYPES.PROMOTE].Add(move);
				else
				{
					legalMoves[pawn][MOVE_TYPES.MOVES].Add(move);
					boolCanGoFoward = true;
				}
			}
		}
		//Double Move From Start
		if( boolCanGoFoward && ( HexState.isWhiteTurn ? isWhitePawnStart(pawn) : isBlackPawnStart(pawn) ) )
		{
			int doubleF = HexState.isWhiteTurn ? pawn.Y - 2 : pawn.Y + 2;
			int index = QRToIndex(pawn.X, doubleF);
			if (BitBoards.IsIndexEmpty(index))
				legalMoves[pawn][MOVE_TYPES.ENPASSANT].Add(new Vector2I(pawn.X, doubleF));
		}
		return;
	}
	// Calculate Pawn Moves
	private void bbfindMovesForPawn(List<Vector2I> PawnArray)
	{
		foreach ( Vector2I pawn in PawnArray)
		{
			legalMoves[pawn] = DeepCopyMoveTemplate(PAWN_MOVE_TEMPLATE);

			int fowardR = HexState.isWhiteTurn ? pawn.Y - 1 : pawn.Y + 1;
			int leftCaptureR = HexState.isWhiteTurn ? pawn.Y : pawn.Y + 1;
			int rightCaptureR = HexState.isWhiteTurn? pawn.Y-1 : pawn.Y;

			//Foward Move
			bbfindFowardMovesForPawn(pawn, fowardR);

			//Left Capture
			bbfindCaptureMovesForPawn(pawn, pawn.X-1, leftCaptureR);

			//Right Capture
			bbfindCaptureMovesForPawn(pawn, pawn.X+1, rightCaptureR);

			// Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(pawn) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[pawn];
				foreach( MOVE_TYPES moveType in legalMoves[pawn].Keys)
					legalMoves[pawn][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[pawn][moveType]);
			}
			// Not Efficient FIX LATER
			if( HexState.isCheck )
				foreach( MOVE_TYPES moveType in legalMoves[pawn].Keys)
					legalMoves[pawn][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[pawn][moveType]);
		}
		return;
	}


	// Knight Moves


	private void  bbfindMovesForKnight(List<Vector2I> KnightArray)
	{
		foreach( Vector2I knight in KnightArray)
		{
			legalMoves[knight] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			var invertAt2Counter = 0;
			foreach( int m in KNIGHT_MULTIPLERS )
			{
				foreach( string dir in KNIGHT_VECTORS.Keys )
				{
					Vector2I activeVector = KNIGHT_VECTORS[dir];
					int checkingQ = knight.X + (( (invertAt2Counter < 2) ? activeVector.X : activeVector.Y) * m);
					int checkingR = knight.Y + (( (invertAt2Counter < 2) ? activeVector.Y : activeVector.X) * m);
					if (Bitboard128.inBitboardRange(checkingQ,checkingR))
					{
						int index = QRToIndex(checkingQ,checkingR);
						updateAttackBoard(checkingQ, checkingR, 1);
						if (BitBoards.IsIndexEmpty(index)) 
							legalMoves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
						else if(BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn)
							legalMoves[knight][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ,checkingR));
					}
				}
				invertAt2Counter += 1;
			}
				
			//Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(knight) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[knight];
				foreach( MOVE_TYPES moveType in legalMoves[knight].Keys)
					legalMoves[knight][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[knight][moveType]);
			}
			// Not Efficient FIX LATER
			if( HexState.isCheck )
				foreach(MOVE_TYPES moveType in legalMoves[knight].Keys)
					legalMoves[knight][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[knight][moveType]);
		}
		return;
	}


	// Rook Moves


	private void bbfindMovesForRook(List<Vector2I> RookArray)
	{
		foreach( Vector2I rook in RookArray)
		{
			legalMoves[rook] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			foreach(string dir in ROOK_VECTORS.Keys)
			{

				Vector2I activeVector = ROOK_VECTORS[dir];
				int checkingQ = rook.X + activeVector.X;
				int checkingR = rook.Y + activeVector.Y;
				while (Bitboard128.inBitboardRange(checkingQ,checkingR))
				{
					var index = QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1);
					if( BitBoards.IsIndexEmpty(index) )
						legalMoves[rook][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
					else
					{
						Vector2I pos = new Vector2I(checkingQ,checkingR);
						if(influencedPieces.ContainsKey(pos)) influencedPieces[pos].Add(rook);
						else influencedPieces[pos] = new List<Vector2I> {rook};
						
						if( BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn ) //Enemy
						{ 
							legalMoves[rook][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
							//King Escape Fix
							if( BitBoards.PieceTypeOf(index, HexState.isWhiteTurn) == PIECES.KING )
							{
								checkingQ += activeVector.X;
								checkingR += activeVector.Y;
								if(Bitboard128.inBitboardRange(checkingQ, checkingR))
									updateAttackBoard(checkingQ, checkingR, 1);
							}
						}
						break;
					}
					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			// Not Efficient TODO: FIX LATER
			if(  blockingPieces.ContainsKey(rook) )
			{
				List<Vector2I> newLegalmoves = blockingPieces[rook];
				foreach( MOVE_TYPES moveType in legalMoves[rook].Keys)
					legalMoves[rook][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[rook][moveType]);
			}
			/// Not Efficient TODO: FIX LATER
			if( HexState.isCheck )
				foreach( MOVE_TYPES moveType in legalMoves[rook].Keys)
					legalMoves[rook][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[rook][moveType]);
		}
		return;
	}


	// Bishop Moves


	private void bbfindMovesForBishop(List<Vector2I> BishopArray)
	{
		foreach( Vector2I bishop in BishopArray)
		{
			legalMoves[bishop] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			foreach( string dir in BISHOP_VECTORS.Keys )
			{
				Vector2I activeVector = BISHOP_VECTORS[dir];
				int checkingQ = bishop.X + activeVector.X;
				int checkingR = bishop.Y + activeVector.Y;
				while ( Bitboard128.inBitboardRange(checkingQ,checkingR) )
				{
					var index = QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1);
					if( BitBoards.IsIndexEmpty(index) )
						legalMoves[bishop][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
					else
					{
						Vector2I pos = new Vector2I(checkingQ,checkingR);
						if(influencedPieces.ContainsKey(pos))
							influencedPieces[pos].Add(bishop);
						else
							influencedPieces[pos] = new List<Vector2I> {bishop};
						
						if( BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn ) // Enemy
						{
							legalMoves[bishop][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
							//King Escape Fix
							if(BitBoards.PieceTypeOf(index, HexState.isWhiteTurn) == PIECES.KING)
							{
								checkingQ += activeVector.X;
								checkingR += activeVector.Y;
								if( Bitboard128.inBitboardRange(checkingQ,checkingR) )
									updateAttackBoard(checkingQ, checkingR, 1);
							}
						}
						break;
					}
					checkingQ += activeVector.X;
					checkingR += activeVector.Y;
				}
			}
			// Not Efficient FIX LATER
			if(  blockingPieces.ContainsKey(bishop) )
			{
				var newLegalmoves = blockingPieces[bishop];
				foreach( MOVE_TYPES moveType in legalMoves[bishop].Keys)
					legalMoves[bishop][moveType] = intersectOfTwoList(newLegalmoves, legalMoves[bishop][moveType]);
			}
			// Not Efficient FIX LATER
			if( HexState.isCheck )
				foreach(MOVE_TYPES moveType in legalMoves[bishop].Keys)
					legalMoves[bishop][moveType] = intersectOfTwoList(GameInCheckMoves, legalMoves[bishop][moveType]);
		}
		return;
	}


	// Queen Moves


	private void bbfindMovesForQueen(List<Vector2I> QueenArray)
	{
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> tempMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> {};
		
		bbfindMovesForRook(QueenArray);
		foreach(Vector2I queen in QueenArray)
			tempMoves[queen] =  DeepCopyInnerDictionary(legalMoves, queen);

		bbfindMovesForBishop(QueenArray);
		
		foreach( Vector2I queen in QueenArray)
			foreach( MOVE_TYPES moveType in tempMoves[queen].Keys)
				foreach( Vector2I move in tempMoves[queen][moveType])
					legalMoves[queen][moveType].Add(move);
		return;
	}


	// King Moves


	private void  bbfindMovesForKing(List<Vector2I> KingArray)
	{
		foreach( Vector2I king in KingArray)
		{
			legalMoves[king] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
			foreach( string dir in KING_VECTORS.Keys)
			{
				Vector2I activeVector = KING_VECTORS[dir];
				int checkingQ = king.X + activeVector.X;
				int checkingR = king.Y + activeVector.Y;
				
				if(Bitboard128.inBitboardRange(checkingQ,checkingR))
				{
					updateAttackBoard(checkingQ, checkingR, 1);
					if(HexState.isWhiteTurn)
					{
						if(BlackAttackBoard[checkingQ][checkingR] > 0)
							continue;
					}
					else
					{
						if(WhiteAttackBoard[checkingQ][checkingR] > 0)
							continue;
					}
					int index = QRToIndex(checkingQ,checkingR);
					if( BitBoards.IsIndexEmpty(index) )
					{
						legalMoves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
					}
					else if( BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn )
						legalMoves[king][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
				}
			}

			// Not Efficient FIX LATER
			if( HexState.isCheck )
			{
				legalMoves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoList(GameInCheckMoves, legalMoves[king][MOVE_TYPES.CAPTURE]);
				foreach( MOVE_TYPES moveType in legalMoves[king].Keys)
				{
					if(moveType == MOVE_TYPES.CAPTURE) continue;
					legalMoves[king][moveType] = differenceOfTwoList(legalMoves[king][moveType], GameInCheckMoves);
				}
			}
		}
		return;
	}


	// Move Gen


	private void generateNextLegalMoves()
	{
		if(HexState.isWhiteTurn)
			resetBoard(WhiteAttackBoard);
		else
			resetBoard(BlackAttackBoard);
		
		blockingPieces = bbcheckForBlockingPiecesFrom(activePieces[(int)(HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][0]);
		legalMoves.Clear();
		
		lastInfluencedPieces = influencedPieces;
		influencedPieces = new Dictionary<Vector2I, List<Vector2I>> {};
			
		bbfindLegalMovesFor(activePieces);
		
		lastInfluencedPieces = null;
		
		return;
	}


	// Move


	// Find the legal moves for a single player given an array of pieces
	private void bbfindLegalMovesFor(Dictionary<PIECES, List<Vector2I>>[] ap)
	{
		startTime = Time.GetTicksUsec();
		Dictionary<PIECES, List<Vector2I>> pieces = ap[(int)(HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)];
		foreach ( PIECES pieceType in pieces.Keys )
		{
			List<Vector2I> singleTypePieces = pieces[pieceType];
			
			if(singleTypePieces.Count() == 0)
				continue;
				
			switch (pieceType)
			{
				case PIECES.PAWN: bbfindMovesForPawn(singleTypePieces); break;
				case PIECES.KNIGHT: bbfindMovesForKnight(singleTypePieces); break;
				case PIECES.ROOK: bbfindMovesForRook(singleTypePieces); break;
				case PIECES.BISHOP: bbfindMovesForBishop(singleTypePieces); break;
				case PIECES.QUEEN: bbfindMovesForQueen(singleTypePieces); break;
				case PIECES.KING: bbfindMovesForKing(singleTypePieces); break;
			}
		}
		stopTime = Time.GetTicksUsec();
		return;
	}
	//SUB Routine
	private Dictionary<PIECES, List<Vector2I>>[] setupActiveForSingle(PIECES type, Vector2I cords, Vector2I lastCords)
	{
		var movedPiece = new Dictionary<PIECES, List<Vector2I>>[2];
		var internalDictionary = new Dictionary<PIECES, List<Vector2I>> {{type, new List<Vector2I>{cords}}};
		//[{ type : [Vector2i(cords)] }];
		
		if (influencedPieces.ContainsKey(lastCords))
		{
			foreach( Vector2I item in influencedPieces[lastCords] )
			{
				var index = QRToIndex(item.X,item.Y);
				if (BitBoards.IsPieceWhite(index) != HexState.isWhiteTurn) continue;
				var inPieceType = BitBoards.PieceTypeOf(index, !HexState.isWhiteTurn);
				if ( internalDictionary.ContainsKey(inPieceType) )
					internalDictionary[inPieceType].Add(item);
				else
					internalDictionary[inPieceType] = new List<Vector2I> { item };
			}
		}
		movedPiece[HexState.isWhiteTurn ? 1 : 0] = internalDictionary;
		return movedPiece;
	}
	private void fillRookCheckMoves(Vector2I kingCords, Vector2I moveToCords)
	{
		var deltaQ = kingCords.X - moveToCords.X;
		var deltaR = kingCords.X - moveToCords.Y;
		var direction = new Vector2I(0,0);

		if(deltaQ > 0)
			direction.X = 1;
		else if (deltaQ < 0)
			direction.X = -1;
		
		if(deltaR > 0)
			direction.Y = 1;
		else if (deltaR < 0)
			direction.Y = -1;

		while( true )
		{
			GameInCheckMoves.Add(moveToCords);
			moveToCords.X += direction.X;
			moveToCords.Y += direction.Y;
			if( Bitboard128.inBitboardRange(moveToCords.X, moveToCords.Y) )
				if(! BitBoards.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y)))
					break;
			else
				break;
		}
		return;
	}
	private void fillBishopCheckMoves(Vector2I kingCords, Vector2I moveToCords)
	{
		var deltaQ = kingCords.X - moveToCords.X;
		var deltaR = kingCords.Y - moveToCords.Y;
		var direction = new Vector2I(0,0);

		if(deltaQ > 0)
			if(deltaR < 0)
				if(Math.Abs(deltaQ) < Math.Abs(deltaR))
					direction = new Vector2I(1,-2);
				else
					direction = new Vector2I(2,-1);
			else if (deltaR > 0)
				direction = new Vector2I(1,1);
		else if (deltaQ < 0)
			if(deltaR > 0)
				if(Math.Abs(deltaQ) < Math.Abs(deltaR))
					direction = new Vector2I(-1,2);
				else
					direction = new Vector2I(-2,1);
			else if (deltaR < 0)
				direction = new Vector2I(-1,-1);
			
		while( true )
		{
			GameInCheckMoves.Add(moveToCords);
			moveToCords.X += direction.X;
			moveToCords.Y += direction.Y;
			if ( Bitboard128.inBitboardRange(moveToCords.X, moveToCords.Y) )
				if(! BitBoards.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y))) break;
			else break;
		}
		return;
	}
	// SUB Routine
	private void fillInCheckMoves(PIECES pieceType, Vector2I cords, Vector2I kingCords, bool clear)
	{
		HexState.GameInCheckFrom = new Vector2I(cords.X, cords.Y);
		if (clear) GameInCheckMoves = new List<Vector2I> {};
		HexState.isCheck = true;
		
		switch( pieceType )
		{
			case PIECES.KING:
				break;
			case PIECES.PAWN: 
			case PIECES.KNIGHT: // Can not be blocked
				GameInCheckMoves.Add(cords);
				break;
			case PIECES.ROOK:
				fillRookCheckMoves(kingCords, cords);
				break;
			case PIECES.BISHOP:
				fillBishopCheckMoves(kingCords, cords);
				break;
			case PIECES.QUEEN:
				if(
					(cords.X == kingCords.X) || //same Q
						(cords.Y == kingCords.Y) || //same R
						(cords.X+cords.Y) == (kingCords.X+kingCords.Y) ) // same s
					fillRookCheckMoves(kingCords, cords);
				else
					fillBishopCheckMoves(kingCords, cords);
				break;
		}
		return;
	}
	private void addInflunceFrom(Vector2I cords)
	{
		foreach( Vector2I v in ROOK_VECTORS.Values)
		{
			var checking = new Vector2I(cords.X,cords.Y) + v;
			while (Bitboard128.inBitboardRange(checking.X, checking.Y))
			{
				if(! BitBoards.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
				{
					if(influencedPieces.ContainsKey(cords))
						influencedPieces[cords].Add(checking);
					else
						influencedPieces[cords] = new List<Vector2I> { checking };
					break;
				}
				checking += v;
			}
		}
			
		foreach( Vector2I v in BISHOP_VECTORS.Values)
		{
			var checking = new Vector2I(cords.X,cords.Y) + v;
			while (Bitboard128.inBitboardRange(checking.X, checking.Y))
			{
				if(! BitBoards.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
				{
					if(influencedPieces.ContainsKey(cords))
						influencedPieces[cords].Add(checking);
					else
						influencedPieces[cords] = new List<Vector2I> { checking };
					break;
				}
				checking += v;
			}
		}
		return;
	}
	private void handleMoveState(Vector2I cords, Vector2I lastCords, HistEntry hist)
	{
		var pieceType = BitBoards.PieceTypeOf(QRToIndex(cords.X,cords.Y), !HexState.isWhiteTurn);
		var movedPiece = setupActiveForSingle(pieceType, cords, lastCords);
		var mateStatus = UNDO_FLAGS.NONE;
		Vector2I kingCords = activePieces[(int)(HexState.isWhiteTurn ?  SIDES.BLACK : SIDES.WHITE)][PIECES.KING][KING_INDEX];

		blockingPieces = bbcheckForBlockingPiecesFrom(activePieces[(int)(HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX]);
		legalMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> {};
		
		BitBoards.clearCombinedStateBitboards();
		BitBoards.generateCombinedStateBitboards();

		bbfindLegalMovesFor(movedPiece);

		if(checkIFCordsUnderAttack(kingCords, legalMoves))
		{
			mateStatus = UNDO_FLAGS.CHECK;
			fillInCheckMoves(pieceType, cords, kingCords, true);
		}
		
		// clearCombinedStateBitboards();
		// generateCombinedStateBitboards();

		addInflunceFrom(cords);

		HexState.incrementTurnNumber();
		HexState.swapPlayerTurn();
		
		generateNextLegalMoves();

		var pieceCount = 0; 
		foreach(var side in activePieces)
			foreach(var  type in side.Keys)
				foreach(var piece in side[type])
					pieceCount+=1;
					
		if(pieceCount <= 2)
			HexState.isOver = true;

		// Check For Mate and Stale Mate	
		var moveCount = countMoves(legalMoves);
		if( moveCount <= 0)
		{
			HexState.isOver = true;
			mateStatus = UNDO_FLAGS.GAME_OVER;
			// #if(HexState.isCheck):
			// 	##print("Check Mate")
			// 	#pass;
			// #else:
			// 	##print("Stale Mate")
			// 	#pass;
		}
		
		if(mateStatus == UNDO_FLAGS.GAME_OVER)
			hist._flipOver();
		else if (mateStatus == UNDO_FLAGS.CHECK)
			hist._flipCheck();
		
		historyStack.Push(hist);
		
		return;
	}
	private bool handleMoveCapture(Vector2I moveTo, PIECES pieceType)
	{
		var revertEnPassant = false;
		var moveToIndex = 	QRToIndex(moveTo.X, moveTo.Y);
		var type = BitBoards.PieceTypeOf(moveToIndex, HexState.isWhiteTurn);
		HexState.captureType = type;
		HexState.captureValid = true;

		// ENPASSANT FIX
		if(pieceType == PIECES.PAWN && BitBoards.IsIndexEmpty(moveToIndex))
		{
			moveTo.Y += HexState.isWhiteTurn ?  1 : -1;
			moveToIndex = QRToIndex(moveTo.X, moveTo.Y);
			HexState.captureType = BitBoards.PieceTypeOf(moveToIndex, HexState.isWhiteTurn);
			revertEnPassant = true;
		}

		if(HexState.captureType == PIECES.KING)
		{
			GD.Print("Sharp ", moveTo, " ", pieceType); 
			foreach(HistEntry hist in historyStack)
			{
				GD.Print(hist);
			}
			GD.Print(" ");
		}

		BitBoards.ClearIndexOf(QRToIndex(moveTo.X,moveTo.Y),!HexState.isWhiteTurn,HexState.captureType);
		
		var opColor = (int)(HexState.isWhiteTurn ? SIDES.BLACK : SIDES.WHITE);
		int i = 0;
		foreach(Vector2I pieceCords in activePieces[opColor][HexState.captureType])
		{
			if(moveTo == pieceCords)
			{
				HexState.captureIndex = i;
				break;
			}
			i += 1;
		}
		activePieces[opColor][HexState.captureType].RemoveAt(i);

		removeCapturedFromATBoard(HexState.captureType, moveTo);

		// ENPASSANT FIX
		if(revertEnPassant)
			moveTo.Y += HexState.isWhiteTurn ? -1 : 1;

		//Add To Captures
		if(HexState.isWhiteTurn) HexState.whiteCaptures.Add(HexState.captureType);
		else HexState.blackCaptures.Add(HexState.captureType);
		return revertEnPassant;
	}
	private void handleMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{
		PIECES pieceType = BitBoards.PieceTypeOf(QRToIndex(cords.X,cords.Y), !HexState.isWhiteTurn);
		int pieceVal = getPieceInt(pieceType, !HexState.isWhiteTurn);
		int previousPieceVal = pieceVal;
		
		int selfColor = (int)( HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK );
		Vector2I moveTo = legalMoves[cords][moveType][moveIndex];
		

		var index = QRToIndex(cords.X,cords.Y);
		BitBoards.ClearIndexFrom(index, HexState.isWhiteTurn);

		HistEntry histEntry = new HistEntry(pieceVal, cords, moveTo);

		switch(moveType)
		{
			case MOVE_TYPES.PROMOTE:
				if(moveTo.X != cords.X)
				{
					histEntry._flipCapture();
					histEntry._setCPieceType((int)HexState.captureType);
					histEntry._setCIndex(HexState.captureIndex);
					handleMoveCapture(moveTo, pieceType);
				}
				int i = 0;
				foreach( Vector2I pieceCords in activePieces[selfColor][pieceType])
				{
					if(cords == pieceCords)
						break;
					i += 1;
				}
				
				activePieces[selfColor][pieceType].RemoveAt(i);
				pieceType = getPieceType((int)promoteTo);
				pieceVal = getPieceInt(pieceType, !HexState.isWhiteTurn);
				activePieces[selfColor][pieceType].Append(moveTo);
				
				histEntry._flipPromote();
				histEntry._setPPieceType((int)pieceType);
				histEntry._setPIndex(i);
				break;
				

			case MOVE_TYPES.ENPASSANT:
				var newECords = legalMoves[cords][MOVE_TYPES.ENPASSANT][0];
				HexState.EnPassantCords = new Vector2I(newECords.X, newECords.Y + (HexState.isWhiteTurn ? 1 : -1));
				HexState.EnPassantTarget = moveTo;
				HexState.EnPassantCordsValid = true;
				histEntry._flipEnPassant();
				break;
				
			case MOVE_TYPES.CAPTURE:
				histEntry._flipCapture();
				if( handleMoveCapture(moveTo, pieceType))
					histEntry._flipTopSneak();
				histEntry._setCIndex(HexState.captureIndex);
				histEntry._setCPieceType((int)HexState.captureType);
				break;

			case MOVE_TYPES.MOVES: break;
		}

		BitBoards.add_IPieceToBitBoardsOf(moveTo.X,moveTo.Y,(int)pieceType,HexState.isWhiteTurn);
		
		// Update Piece List
		for(int i = 0; i < activePieces[selfColor][pieceType].Count; i += 1)
			if (activePieces[selfColor][pieceType][i] == cords)
			{
				activePieces[selfColor][pieceType][i] = moveTo;
				break;
			}

		removeAttacksFrom(cords, getPieceType(previousPieceVal));
		
		handleMoveState(moveTo, cords, histEntry);

		return;
	}


	// Move Undo

	
	// SUB Routine
	private void undoSubCleanFlags(Vector2I from, Vector2I to, HistEntry hist)
	{
		var selfSide = (int)( HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK );
		
		if(hist._getEnPassant()) HexState.EnPassantCordsValid = false;
		if(hist._getOver()) HexState.isOver = false;
		if(hist._getCheck()) HexState.isCheck = false;
		
		if(hist._getPromote())
		{
			BitBoards.AddPieceOf(QRToIndex(to.X, to.Y), HexState.isWhiteTurn, PIECES.PAWN);
			BitBoards.ClearIndexOf(QRToIndex(to.X, to.Y), HexState.isWhiteTurn, (PIECES) hist._getPPieceType());
			
			int size = activePieces[selfSide][(PIECES) hist._getPPieceType()].Count;
			activePieces[selfSide][(PIECES) hist._getPPieceType()].RemoveAt(size-1);
			activePieces[selfSide][PIECES.PAWN].Insert( hist._getPIndex(), new Vector2I(from.X,from.Y) );
			
			unpromoteValid = true;
			unpromoteIndex = hist._getPIndex();
			unpromoteType = (PIECES) hist._getPPieceType();
		}
		if(hist._getCapture())
		{
			if(hist._getIsCaptureTopSneak())
				to.Y += HexState.isWhiteTurn ? 1 :-1;
			BitBoards.AddPieceOf(QRToIndex(to.X, to.Y), !HexState.isWhiteTurn, (PIECES) hist._getCPieceType());
			activePieces[(int)(HexState.isWhiteTurn ? SIDES.BLACK : SIDES.WHITE)][(PIECES)hist._getCPieceType()].Insert( hist._getCIndex(), new Vector2I(to.X,to.Y) );
				
			uncaptureValid = true;
			HexState.captureIndex = hist._getCIndex();
			HexState.captureType = (PIECES) hist._getCPieceType();
			
			addInflunceFrom(to);
		}
		return;
	}
	// SUB Routine
	// Moves should be generated by caller function afterwards
	private void undoSubFixState(){
		if(historyStack.Count <= 0)
			return;
		
		var history = historyStack.Pop();
		historyStack.Push(history);

		if(history._getCheck())
		{
			var kingCords = activePieces[(int)( HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
			var attacker = bbsearchForMyAttackers(kingCords, HexState.isWhiteTurn);
			GameInCheckMoves = new List<Vector2I> {};
			HexState.isCheck = true;
			foreach(Vector2I atk in attacker)
			{
				PIECES pieceType = BitBoards.PieceTypeOf(QRToIndex(atk.X, atk.Y), HexState.isWhiteTurn);
				fillInCheckMoves(pieceType, atk, kingCords, false);
			}
		}	
		if(history._getEnPassant())
		{
			HexState.EnPassantCordsValid = true;
			var from = history._getFrom();
			var to = history._getTo();
			var side = ((from - to).Y) < 0 ? SIDES.BLACK : SIDES.WHITE;
			HexState.EnPassantTarget = to;
			HexState.EnPassantCords = new Vector2I(to.X, to.Y - (side == SIDES.BLACK ? 1 : -1));
		}
		return;
	}
	public static Dictionary<int, Dictionary<int, int>> DeepCopyBoard(Dictionary<int, Dictionary<int, int>> original)
	{
		var copy = new Dictionary<int, Dictionary<int, int>>();
		foreach (var outerPair in original)
		{
			var innerCopy = new Dictionary<int, int>(outerPair.Value);
			copy.Add(outerPair.Key, innerCopy);
		}
		return copy;
	}
	public static Dictionary<Vector2I, List<Vector2I>> DeepCopyPieces(Dictionary<Vector2I, List<Vector2I>> original)
	{
		var copy = new Dictionary<Vector2I, List<Vector2I>>();
		foreach (var outerPair in original)
		{
			var listCopy = new List<Vector2I>(outerPair.Value.Select(v => new Vector2I(v.X, v.Y)));
			copy.Add(outerPair.Key, listCopy);
		}
		return copy;
	}

	
	public void _restoreState(
		Dictionary<int, Dictionary<int,int>> WABoard,
		Dictionary<int, Dictionary<int,int>> BABoard,
		Dictionary<Vector2I, List<Vector2I>> BPieces,
		Dictionary<Vector2I, List<Vector2I>> IPieces,
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> moves)
	{
		WhiteAttackBoard = DeepCopyBoard(WABoard);
		BlackAttackBoard = DeepCopyBoard(BABoard);
		blockingPieces = DeepCopyPieces(BPieces);
		influencedPieces = DeepCopyPieces(IPieces);
		legalMoves = DeepCopyLegalMoves(moves);
		return;
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateWAB()
	{
		return DeepCopyBoard(WhiteAttackBoard);
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateBAB()
	{
		return DeepCopyBoard(BlackAttackBoard);
	}	
	public Dictionary<Vector2I, List<Vector2I>> _duplicateBP()
	{
		return DeepCopyPieces(blockingPieces);
	}
	public Dictionary<Vector2I, List<Vector2I>>  _duplicateIP()
	{
		return DeepCopyPieces(influencedPieces);
	}


	//Init


	private void initiateEngineAI()
	{
		if(! Enemy.EnemyIsAI)
			return;
		switch (Enemy.EnemyType)
		{
			case ENEMY_TYPES.RANDOM:
				Enemy.EnemyAI = new RandomAI(Enemy.EnemyPlaysWhite);
				break;
			case ENEMY_TYPES.MIN_MAX:
				Enemy.EnemyAI = new MinMaxAI(Enemy.EnemyPlaysWhite, 2);
				break;
			case ENEMY_TYPES.NN:
				GD.PushWarning("NN Agent not yet implemented, using RNG");
				Enemy.EnemyAI = new RandomAI(Enemy.EnemyPlaysWhite);
				break;
		}
		return;
	}
	// initiate the engine with a new game
	public bool initiateEngine(string FEN_STRING)
	{
		if ( ! fillBoardwithFEN(FEN_STRING) )
		{
			GD.PushError("Invalid FEN STRING");
			return false;
		}

		WhiteAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
		BlackAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);

		historyStack = new Stack<HistEntry> {};

		HexState.blackCaptures.Clear();
		HexState.whiteCaptures.Clear();

		GameInCheckMoves = new List<Vector2I> {};
		legalMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> {};
		blockingPieces = new Dictionary<Vector2I, List<Vector2I>> {};
		
		bypassMoveLock = false;
		HexState.isOver = false;
		HexState.isCheck = false;
		HexState.captureValid = false;
		HexState.GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);

		activePieces = BitBoards.bbfindPieces();

		generateNextLegalMoves();

		initiateEngineAI();

		return true;		
	}


	// API


	// Enemy is shorter than opponent
	public void _setEnemy(ENEMY_TYPES type, bool isWhite)
	{
		Enemy.EnemyType = type;
		if(Enemy.EnemyType < ENEMY_TYPES.RANDOM)
			Enemy.EnemyIsAI = false;
		else
			Enemy.EnemyIsAI = true;
		Enemy.EnemyPlaysWhite = isWhite;
		return;
	}
	public void _disableAIMoveLock()
	{
		bypassMoveLock = false;
		return;
	}
	public void _enableAIMoveLock()
	{
		bypassMoveLock = true;
		return;
	}
	//## MAKE MOVE PUBLIC CALL
	//# TODO:: HANDLE IN PROPER INPUT FEEDBACK
	public void _makeMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{

		if(HexState.isOver)
		{
			GD.PushWarning("Game Is Over");
			return;
		}

		if(!legalMoves.ContainsKey(cords))
		{
			GD.PushWarning("Invalid Move Attempted");
			return;
		}

		if(Enemy.EnemyIsAI)
			if (bypassMoveLock && (Enemy.EnemyPlaysWhite == HexState.isWhiteTurn))
			{
				GD.PushError($"It is not your turn. Is AI Turn: {Enemy.EnemyPlaysWhite == HexState.isWhiteTurn}");
				return;
			}

		resetTurnFlags();
		handleMove(cords, moveType, moveIndex, promoteTo);
		return;
	}
	public void _passToAI()
	{
		if(HexState.isOver)
			return;
		
		Enemy.EnemyAI._makeChoice(this);
		
		Enemy.EnemyChoiceType = BitBoards.PieceTypeOf(QRToIndex(Enemy.EnemyAI._getCords().X,Enemy.EnemyAI._getCords().Y),  !HexState.isWhiteTurn);
		
		Enemy.EnemyTo = Enemy.EnemyAI._getTo();
		
		Enemy.EnemyPromoted = Enemy.EnemyAI._getMoveType() == (int) MOVE_TYPES.PROMOTE;
		Enemy.EnemyPromotedTo = (PIECES) Enemy.EnemyAI._getPromoteTo();

		Enemy.EnemyChoiceIndex = 0;
		foreach( Vector2I pieceCords in activePieces[(int)(HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][Enemy.EnemyChoiceType])
		{
			if(pieceCords == Enemy.EnemyAI._getCords()) break;
			Enemy.EnemyChoiceIndex += 1;
		}
		
		resetTurnFlags();
		
		handleMove(Enemy.EnemyAI._getCords(), (MOVE_TYPES) Enemy.EnemyAI._getMoveType(), Enemy.EnemyAI._getMoveIndex(), Enemy.EnemyPromotedTo);
		return;
	}
	// RESIGN PUBLIC 
	private void _resign()
	{
		BitBoards.clearCombinedStateBitboards();
		BitBoards.clearStateBitboard();
		if(HexState.isOver)
			return;
		HexState.isOver = true;
		return;
	}
	// Undo Move PUBLIC CALL
	public bool _undoLastMove(bool genMoves = true)
	{
		if(historyStack.Count < 1)
			return false;
		
		uncaptureValid = false;
		unpromoteValid = false;
		HexState.decrementTurnNumber();
		HexState.swapPlayerTurn();
		
		var activeMove = historyStack.Pop();
		var pieceVal = activeMove._getPiece();
		var UndoNewFrom = activeMove._getFrom();
		var UndoNewTo = activeMove._getTo();
		
		var pieceType = getPieceType(pieceVal);
		var selfColor = (int)( HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK);
		int index = 0;
		
		// Default Undo
		BitBoards.ClearIndexOf(QRToIndex(UndoNewTo.X,UndoNewTo.Y), HexState.isWhiteTurn, pieceType);
		BitBoards.AddPieceOf(QRToIndex(UndoNewFrom.X,UndoNewFrom.Y), HexState.isWhiteTurn, pieceType);
		
		foreach( Vector2I pieceCords in activePieces[selfColor][pieceType] )
		{
			if(pieceCords == UndoNewTo)
			{
				activePieces[selfColor][pieceType][index] = UndoNewFrom;
				//#if (index < activePieces[selfColor][pieceType].size() ): 
				//# After a promotion pawn does not exist to move back
				break;
			}
			index += 1;
		}
		
		undoType = pieceType;
		undoIndex = index;
		
		undoSubCleanFlags(UndoNewFrom, UndoNewTo, activeMove);
		undoSubFixState();
		
		addInflunceFrom(UndoNewFrom);
		
		BitBoards.clearCombinedStateBitboards();
		BitBoards.generateCombinedStateBitboards();
		
		activeMove = null;
		
		if(genMoves) 
			generateNextLegalMoves();
		return true;
	}
	//START DEFAULT GAME PUBLIC CALL
	public bool _initDefault()
	{
		return initiateEngine(FENConst.DEFAULT_FEN_STRING);
	}


	// Get


	public bool _getUncaptureValid()
	{
		return uncaptureValid;
	}
	public bool _getUnpromoteValid()
	{
		return unpromoteValid;
	}
	public bool _getIsWhiteTurn()
	{
		return HexState.isWhiteTurn;
	}
	public bool _getIsBlackTurn()
	{
		return !HexState.isWhiteTurn;
	}
	public bool _getEnemyIsWhite()
	{
		return Enemy.EnemyPlaysWhite;
	} 
	public bool _getIsEnemyAI()
	{
		return Enemy.EnemyIsAI;
	}
	public bool _getGameOverStatus()
	{
		return HexState.isOver;
	}
	public bool _getCaptureValid()
	{
		return HexState.captureValid;
	}
	public bool _getGameInCheck()
	{
		return HexState.isCheck;
	}
	public bool _getEnemyPromoted()
	{
		return Enemy.EnemyPromoted;
	}

	public int _getEnemyPTo()
	{
		return (int) Enemy.EnemyPromotedTo;
	}
	public int _getCaptureType()
	{
		return (int) HexState.captureType;
	}
	public int _getCaptureIndex()
	{
		return HexState.captureIndex;
	}
	public int _getMoveHistorySize()
	{
		return historyStack.Count;
	}
	public int _getUndoType()
	{
		return (int) undoType;
	}
	public int _getUndoIndex()
	{
		return undoIndex;
	}
	public int _getEnemyChoiceType()
	{
		return (int) Enemy.EnemyChoiceType;
	}
	public int _getEnemyChoiceIndex()
	{
		return Enemy.EnemyChoiceIndex;
	}
	
	public Vector2I _getEnemyTo()
	{
		return Enemy.EnemyTo;
	}

	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> _getmoves()
	{
		return legalMoves;
	}

	public Dictionary<PIECES, List<Vector2I>>[] _getAP()
	{
		return activePieces;
	}

	// GDSCRIPT INTERACTIONS

	public Godot.Collections.Array<Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>> _getActivePieces()
	{
		var gdReturn = new Godot.Collections.Array<Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>>();
		foreach(var side in activePieces)
		{
			var innerDictionary = new Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>();
			foreach(var key in side.Keys)
			{
				var innerList = new Godot.Collections.Array<Vector2I>();
				foreach(var piece in side[key])
				{
					innerList.Add(piece);
				}
				innerDictionary.Add(key, innerList);
			}
			gdReturn.Add(innerDictionary);
		}
		return gdReturn;
	}
	public Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>> _getMoves()
	{
		var gdReturn = new Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>>();
		foreach(var key in legalMoves.Keys)
		{
			var innerDictionary = new Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>();
			foreach(var innerkey in legalMoves[key].Keys)
			{
				var innerList = new Godot.Collections.Array<Vector2I>();
				foreach(var piece in legalMoves[key][innerkey])
				{
					innerList.Add(piece);
				}
				innerDictionary.Add(innerkey, innerList);
			}
			gdReturn.Add(key, innerDictionary);
		}
		return gdReturn;
	} 


	// Test


	public void test()
	{
		GD.Print("Test");
		count_moves(2);
		GD.Print("HexEngineSharp Moves Counted:");
		GD.Print("Counter: ", counter);
		GD.Print(": ", totalTime, "\n");
	}
	private void trymove(int depth)
	{
		if(depth == 0 || _getGameOverStatus())
		{
			return;
		}
		var legalmoves = DeepCopyLegalMoves(legalMoves);
		foreach( Vector2I piece in legalmoves.Keys)
		{
			foreach(MOVE_TYPES movetype in legalmoves[piece].Keys)
			{
				int index = 0;
				foreach(Vector2I move in legalmoves[piece][movetype])
				{
					
					// using (StreamWriter writer = new StreamWriter(path, append: true))
					// {
					//  	writer.WriteLine($"{piece}, {movetype}, {move}");
					// }
					counter += 1;
					var WAB = _duplicateWAB();
					var BAB = _duplicateBAB();
					var BP = _duplicateBP();
					var InPi = _duplicateIP();
					_makeMove(piece, movetype, index, PIECES.QUEEN);
					totalTime += (stopTime - startTime);
					trymove(depth-1);
					_undoLastMove(false);
					_restoreState(WAB,BAB,BP,InPi,legalmoves);
					
				}
			}
		}
		return ;
	}	
	private int counter;
	private ulong totalTime;
	private string path = "sharplog.txt";
	private int count_moves(int depth)
	{
		if (depth <= 0)
			return 0;
		counter = 0;
		totalTime = 0;
		_initDefault();
		trymove(depth);
		_resign();
		return counter;
	}

}