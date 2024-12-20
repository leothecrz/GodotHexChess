
using System;
using System.Collections.Generic;
using System.Numerics;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{

//TODO :: Offload onto GPU?

public class HexMoveGenerator
{
	//MOVE DICT
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> moves {get; set;}

	//ATK
	public Dictionary<int, Dictionary<int,int>> WhiteAttackBoard {get; set;}
	public Dictionary<int, Dictionary<int,int>> BlackAttackBoard {get; set;}

	//PIECES
	private Dictionary<Vector2I, List<Vector2I>> lastInfluencedPieces {get; set;}
	public Dictionary<Vector2I, List<Vector2I>> influencedPieces {get; set;}
	public Dictionary<Vector2I, List<Vector2I>> blockingPieces {get; set;}

	//CHECK
	public List<Vector2I> GameInCheckMoves {get; set;}

	//KING
	private Vector2I myKingCords;

	//REFS
	private BoardState BoardRef;
	private BitboardState BBRef;

	//Testing
	public ulong startTime = 0 ;
	public ulong stopTime = 0;
	public double runningAVG = 0;
	public int count = -1;

	public HexMoveGenerator(ref BoardState bref, ref BitboardState bbref)
	{
		BoardRef = bref;
		BBRef = bbref;
		
		influencedPieces = new Dictionary<Vector2I, List<Vector2I>>();
		lastInfluencedPieces = new Dictionary<Vector2I, List<Vector2I>>(); 

		blockingPieces = new Dictionary<Vector2I, List<Vector2I>> {};

		GameInCheckMoves = new List<Vector2I> {};

		WhiteAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
		BlackAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
	}
	//Utility
	public void updateRunningAverage()
	{
		if(count <= 0)
			return;
		double time = stopTime - startTime;
		runningAVG += ((time - runningAVG)/count);
	}

	//Static
	public static Dictionary<int,Dictionary<int,int>> createAttackBoard(int radius)
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


	//Based on the turn determine the appropriate board to update.
	private void updateAttackBoard(int q, int r, int mod, bool modw)
	{
		if(modw)
			WhiteAttackBoard[q][r] += mod;
		else
			BlackAttackBoard[q][r] += mod;
		return;
	}


	// Pawn Moves
	public bool EnPassantLegal()
	{
		Vector2I targetPos = new Vector2I(BoardRef.EnPassantCords.X, BoardRef.EnPassantCords.Y + ( BoardRef.IsWhiteTurn ? 1 : -1));
		
		foreach( Vector2I piece in lastInfluencedPieces[targetPos])
		{
			int index = QRToIndex(piece.X,piece.Y);
			if(BBRef.IsPieceWhite(index) == BoardRef.IsWhiteTurn) continue;
			PIECES type = BBRef.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn);
			if(type == PIECES.ROOK || type == PIECES.QUEEN)
			{
				if ( piece.X == myKingCords.X ) return false;
				else if ( piece.Y == myKingCords.Y ) return false;
				else if ( SAxialCordFrom(piece) == SAxialCordFrom(myKingCords) ) return false;
			}
			if(type == PIECES.BISHOP || type == PIECES.QUEEN)
			{
				var differenceS = SAxialCordFrom(piece) - SAxialCordFrom(myKingCords);
				if(piece.X - myKingCords.X == piece.Y - myKingCords.Y) return false;
				else if(piece.X - myKingCords.X == differenceS ) return false;
				else if(piece.Y - myKingCords.Y == differenceS ) return false;
			}
		}
		return true;
	}
	private void findCaptureMovesForPawn(Vector2I pawn, int qpos, int rpos)
	{
		if ( ! Bitboard128.IsLegalHexCords(qpos, rpos) ) return;
			
		Vector2I move = new Vector2I(qpos, rpos);
		int index = QRToIndex(qpos,rpos);
		
		if ( BBRef.IsIndexEmpty(index) )
		{
			if( BoardRef.EnPassantCordsValid ) 
				if ( (BoardRef.EnPassantCords.X == qpos) && (BoardRef.EnPassantCords.Y == rpos) )
					if( EnPassantLegal() )
						moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		}
		else
		{
			if(BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn)
			{
				if ( BoardRef.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					moves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
			}
		}
		
		updateAttackBoard(qpos, rpos, 1,BoardRef.IsWhiteTurn);
		return;
	}
	private void findFowardMovesForPawn(Vector2I pawn, int fowardR)
	{
		Vector2I move = new Vector2I(pawn.X,fowardR);
		bool boolCanGoFoward = false;
		// Foward Move
		if (Bitboard128.IsLegalHexCords(pawn.X, fowardR))
		{
			int index = QRToIndex(pawn.X,fowardR);
			if(BBRef.IsIndexEmpty(index))
			{
				if ( BoardRef.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					moves[pawn][MOVE_TYPES.PROMOTE].Add(move);
				else
				{
					moves[pawn][MOVE_TYPES.MOVES].Add(move);
					boolCanGoFoward = true;
				}
			}
		}
		//Double Move From Start
		if( boolCanGoFoward && ( BoardRef.IsWhiteTurn ? isWhitePawnStart(pawn) : isBlackPawnStart(pawn) ) )
		{
			int doubleF = BoardRef.IsWhiteTurn ? pawn.Y - 2 : pawn.Y + 2;
			int index = QRToIndex(pawn.X, doubleF);
			if (BBRef.IsIndexEmpty(index))
				moves[pawn][MOVE_TYPES.ENPASSANT].Add(new Vector2I(pawn.X, doubleF));
		}
		return;
	}
	private void findMovesForPawn(Vector2I pawn)
	{
		int fowardR = BoardRef.IsWhiteTurn ? pawn.Y - 1 : pawn.Y + 1;
		int leftCaptureR = BoardRef.IsWhiteTurn ? pawn.Y : pawn.Y + 1;
		int rightCaptureR = BoardRef.IsWhiteTurn? pawn.Y-1 : pawn.Y;

		moves[pawn] = DeepCopyMoveTemplate(PAWN_MOVE_TEMPLATE);

		//Foward Move
		findFowardMovesForPawn(pawn, fowardR);

		//Left Capture
		findCaptureMovesForPawn(pawn, pawn.X-1, leftCaptureR);

		//Right Capture
		findCaptureMovesForPawn(pawn, pawn.X+1, rightCaptureR);

		// TODO:: Not Efficient FIX LATER
		if(  blockingPieces.ContainsKey(pawn) )
		{
			List<Vector2I> newLegalmoves = blockingPieces[pawn];
			foreach( MOVE_TYPES moveType in moves[pawn].Keys)
				moves[pawn][moveType] = intersectOfTwoList(newLegalmoves, moves[pawn][moveType]);
		}
		// TODO:: Not Efficient FIX LATER
		if( BoardRef.IsCheck )
			foreach( MOVE_TYPES moveType in moves[pawn].Keys)
				moves[pawn][moveType] = intersectOfTwoList(GameInCheckMoves, moves[pawn][moveType]);
	}
	private void findMovesForPawns(List<Vector2I> PawnArray)
	{
		foreach ( Vector2I pawn in PawnArray)
			findMovesForPawn(pawn);
		return;
	}
	
	private Bitboard128 pawnMaskFrom(int index)
	{
		
		return null;
	}
	
	// Knight Moves
	private void findMovesforKnight(Vector2I knight)
	{
		moves[knight] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
		var invertAt2Counter = 0;
		foreach( int m in KNIGHT_MULTIPLERS )
		{
			foreach( string dir in KNIGHT_VECTORS.Keys )
			{
				Vector2I activeVector = KNIGHT_VECTORS[dir];
				int checkingQ = knight.X + (( (invertAt2Counter < 2) ? activeVector.X : activeVector.Y) * m);
				int checkingR = knight.Y + (( (invertAt2Counter < 2) ? activeVector.Y : activeVector.X) * m);
				if (Bitboard128.IsLegalHexCords(checkingQ,checkingR))
				{
					int index = QRToIndex(checkingQ,checkingR);
					updateAttackBoard(checkingQ, checkingR, 1, BoardRef.IsWhiteTurn);
					if (BBRef.IsIndexEmpty(index)) 
						moves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
					else if(BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn)
						moves[knight][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ,checkingR));
				}
			}
			invertAt2Counter += 1;
		}
			
		//Not Efficient FIX LATER
		if(  blockingPieces.ContainsKey(knight) )
		{
			List<Vector2I> newLegalmoves = blockingPieces[knight];
			foreach( MOVE_TYPES moveType in moves[knight].Keys)
				moves[knight][moveType] = intersectOfTwoList(newLegalmoves, moves[knight][moveType]);
		}
		// Not Efficient FIX LATER
		if( BoardRef.IsCheck )
			foreach(MOVE_TYPES moveType in moves[knight].Keys)
				moves[knight][moveType] = intersectOfTwoList(GameInCheckMoves, moves[knight][moveType]);

		return;
	}
	private void findMovesForKnights(List<Vector2I> KnightArray)
	{
		foreach( Vector2I knight in KnightArray)
			findMovesforKnight(knight);
		return;
	}
	
	
	// Rook Moves
	private void findMovesForRook(Vector2I rook)
	{
		moves[rook] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
		foreach(string dir in ROOK_VECTORS.Keys)
		{
			Vector2I activeVector = ROOK_VECTORS[dir];
			int checkingQ = rook.X + activeVector.X;
			int checkingR = rook.Y + activeVector.Y;
			while (Bitboard128.IsLegalHexCords(checkingQ,checkingR))
			{
				var index = QRToIndex(checkingQ,checkingR);
				updateAttackBoard(checkingQ, checkingR, 1, BoardRef.IsWhiteTurn);
				if( BBRef.IsIndexEmpty(index) )
					moves[rook][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos)) influencedPieces[pos].Add(rook);
					else influencedPieces[pos] = new List<Vector2I> {rook};
					
					if( BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn ) //Enemy
					{ 
						moves[rook][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if( BBRef.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn) == PIECES.KING )
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if(Bitboard128.IsLegalHexCords(checkingQ, checkingR))
								updateAttackBoard(checkingQ, checkingR, 1, BoardRef.IsWhiteTurn);
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
			foreach( MOVE_TYPES moveType in moves[rook].Keys)
				moves[rook][moveType] = intersectOfTwoList(newLegalmoves, moves[rook][moveType]);
		}

		/// Not Efficient TODO: FIX LATER
		if( BoardRef.IsCheck )
			foreach( MOVE_TYPES moveType in moves[rook].Keys)
				moves[rook][moveType] = intersectOfTwoList(GameInCheckMoves, moves[rook][moveType]);

		return;
	}
	private void findMovesForRooks(List<Vector2I> RookArray)
	{
		foreach( Vector2I rook in RookArray)
			findMovesForRook(rook);
		return;
	}
	
	
	// Bishop Moves
	private void findMovesForBishop(Vector2I bishop)
	{
		moves[bishop] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
		foreach( string dir in BISHOP_VECTORS.Keys )
		{
			Vector2I activeVector = BISHOP_VECTORS[dir];
			int checkingQ = bishop.X + activeVector.X;
			int checkingR = bishop.Y + activeVector.Y;
			while ( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
			{
				var index = QRToIndex(checkingQ,checkingR);
				updateAttackBoard(checkingQ, checkingR, 1, BoardRef.IsWhiteTurn);
				if( BBRef.IsIndexEmpty(index) )
					moves[bishop][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos))
						influencedPieces[pos].Add(bishop);
					else
						influencedPieces[pos] = new List<Vector2I> {bishop};
					
					if( BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn ) // Enemy
					{
						moves[bishop][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if(BBRef.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn) == PIECES.KING)
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
								updateAttackBoard(checkingQ, checkingR, 1 , BoardRef.IsWhiteTurn);
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
			foreach( MOVE_TYPES moveType in moves[bishop].Keys)
				moves[bishop][moveType] = intersectOfTwoList(newLegalmoves, moves[bishop][moveType]);
		}

		// Not Efficient FIX LATER
		if( BoardRef.IsCheck )
			foreach(MOVE_TYPES moveType in moves[bishop].Keys)
				moves[bishop][moveType] = intersectOfTwoList(GameInCheckMoves, moves[bishop][moveType]);
		
		return;
	}
	private void findMovesForBishops(List<Vector2I> BishopArray)
	{
		foreach( Vector2I bishop in BishopArray)
		{
			findMovesForBishop(bishop);
		}
		return;
	}
	
	
	// Queen Moves
	private void findMovesForQueens(List<Vector2I> QueenArray)
	{
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> tempMoves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> {};
		
		findMovesForRooks(QueenArray);
		foreach(Vector2I queen in QueenArray)
			tempMoves[queen] =  DeepCopyInnerDictionary(moves, queen);

		findMovesForBishops(QueenArray);
		foreach( Vector2I queen in QueenArray)
			foreach( MOVE_TYPES moveType in tempMoves[queen].Keys)
				foreach( Vector2I move in tempMoves[queen][moveType])
					moves[queen][moveType].Add(move);

		return;
	}
	
	
	// King Moves
	private void findMovesForKing(Vector2I king)
	{
		moves[king] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);

		foreach( string dir in KING_VECTORS.Keys)
		{
			Vector2I activeVector = KING_VECTORS[dir];
			int checkingQ = king.X + activeVector.X;
			int checkingR = king.Y + activeVector.Y;
			
			if(!Bitboard128.IsLegalHexCords(checkingQ,checkingR))
				continue;

			updateAttackBoard(checkingQ, checkingR, 1, BoardRef.IsWhiteTurn);
			if(BoardRef.IsWhiteTurn)
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

			if( BBRef.IsIndexEmpty(index) )
			{
				moves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
			}
			else if( BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn )
				moves[king][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
			
		}

		// Not Efficient FIX LATER
		if( BoardRef.IsCheck )
		{
			moves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoList(GameInCheckMoves, moves[king][MOVE_TYPES.CAPTURE]);
			foreach( MOVE_TYPES moveType in moves[king].Keys)
			{
				if(moveType == MOVE_TYPES.CAPTURE) continue;
				moves[king][moveType] = differenceOfTwoList(moves[king][moveType], GameInCheckMoves);
			}
		}

		return;
	}
	private void findMovesForKings(List<Vector2I> KingArray)
	{
		foreach( Vector2I king in KingArray)
			findMovesForKing(king);
		return;
	}



	// Find the legal moves for a single player given an array of pieces
	// Internal Use // Only Call If Prep was manually done.
	public void findLegalMovesFor(Dictionary<PIECES, List<Vector2I>> pieces)
	{
		moves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>>();

		count += 1;
		startTime = Time.GetTicksUsec();

		foreach ( PIECES pieceType in pieces.Keys )
		{
			List<Vector2I> singleTypePieces = pieces[pieceType];
			
			if(singleTypePieces.Count == 0)
				continue;
				
			switch (pieceType)
			{
				case PIECES.PAWN: findMovesForPawns(singleTypePieces); break;
				case PIECES.KNIGHT: findMovesForKnights(singleTypePieces); break;
				case PIECES.ROOK: findMovesForRooks(singleTypePieces); break;
				case PIECES.BISHOP: findMovesForBishops(singleTypePieces); break;
				case PIECES.QUEEN: findMovesForQueens(singleTypePieces); break;
				case PIECES.KING: findMovesForKings(singleTypePieces); break;
			}
		}
		
		stopTime = Time.GetTicksUsec();
		updateRunningAverage();

		//GD.Print($"Running iteration: {count}, Time: {stopTime-startTime}");
		//GD.Print("Running Move Gen Average ", runningAVG);

		return;
	}


	// Attack Board
	private void removePawnAttacks(Vector2I cords)
	{
		//FIX
		var leftCaptureR = BoardRef.IsWhiteTurn ?  cords.Y : cords.Y + 1;
		var rightCaptureR = BoardRef.IsWhiteTurn ? cords.Y-1 : cords.Y;
		//Left Capture
		if( Bitboard128.IsLegalHexCords(cords.X-1, leftCaptureR) )
			updateAttackBoard(cords.X-1, leftCaptureR, -1, BoardRef.IsWhiteTurn);
		//Right Capture
		if( Bitboard128.IsLegalHexCords(cords.X+1, rightCaptureR) )
			updateAttackBoard(cords.X+1, rightCaptureR, -1, BoardRef.IsWhiteTurn);
		return;
	}
	public void rmvSelfAtks(Vector2I cords, PIECES id) 
	{
		if(id == PIECES.PAWN)
		{
			removePawnAttacks(cords);
			return;
		}
				
		foreach( MOVE_TYPES moveType in moves[cords].Keys)
			foreach( Vector2I move in moves[cords][moveType])
				updateAttackBoard(move.X, move.Y, -1, BoardRef.IsWhiteTurn);
		
		return;
	}
	public void removeCapturedFromATBoard(PIECES pieceType, Vector2I cords)
	{
		BoardRef.IsWhiteTurn = !BoardRef.IsWhiteTurn;
		
		var movedPiece = new Dictionary<PIECES, List<Vector2I>> { {pieceType, new List<Vector2I> {new Vector2I(cords.X, cords.Y)}} };
		
		var savedMoves = moves;
		findLegalMovesFor(movedPiece);
		rmvSelfAtks(cords, pieceType);
		moves = savedMoves;
		
		BoardRef.IsWhiteTurn = !BoardRef.IsWhiteTurn;
		return;
	}


	//Influence
	public void addInflunceFrom(Vector2I cords)
	{
		foreach( Vector2I v in ROOK_VECTORS.Values)
		{
			var checking = new Vector2I(cords.X,cords.Y) + v;
			while (Bitboard128.IsLegalHexCords(checking.X, checking.Y))
			{
				if(! BBRef.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
			while (Bitboard128.IsLegalHexCords(checking.X, checking.Y))
			{
				if(! BBRef.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
	//SUB Routine
	public Dictionary<PIECES, List<Vector2I>> setupActiveForSingle(PIECES type, Vector2I cords, Vector2I lastCords)
	{
		var internalDictionary = new Dictionary<PIECES, List<Vector2I>> {{type, new List<Vector2I>{cords}}};
		
		if (influencedPieces.ContainsKey(lastCords))
		{
			foreach( Vector2I item in influencedPieces[lastCords] )
			{
				var index = QRToIndex(item.X,item.Y);
				if (BBRef.IsPieceWhite(index) != BoardRef.IsWhiteTurn) continue;
				var inPieceType = BBRef.GetPieceTypeFrom(index, BoardRef.IsWhiteTurn);
				if ( internalDictionary.ContainsKey(inPieceType) )
					internalDictionary[inPieceType].Add(item);
				else
					internalDictionary[inPieceType] = new List<Vector2I> { item };
			}
		}
		return internalDictionary;
	}


	//Blocking
	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private void bbcheckForBlockingOnVector(PIECES piece, Dictionary<string,Vector2I> dirSet, Dictionary<Vector2I, List<Vector2I>> bp, Vector2I cords)
		{
			var index = QRToIndex(cords.X,cords.Y);
			var isWhiteTrn = BBRef.IsPieceWhite(index);
			
			foreach( string direction in dirSet.Keys )
			{
				List<Vector2I> LegalMoves = new List<Vector2I> {};
				
				Vector2I dirBlockingPiece = new Vector2I(HEX_BOARD_RADIUS+1, HEX_BOARD_RADIUS+1);
				Vector2I activeVector = dirSet[direction];
				
				int checkingQ = cords.X + activeVector.X;
				int checkingR = cords.Y + activeVector.Y;
				
				while ( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
				{
					index = QRToIndex(checkingQ,checkingR);
					if( BBRef.IsIndexEmpty(index) )
					{
						if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
							LegalMoves.Add(new Vector2I(checkingQ,checkingR)); // Track legal moves for the blocking pieces
					}
					else
					{
						if( BBRef.IsPieceWhite(index) == isWhiteTrn ) // Friend Piece
						{
							if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1) break; // Two friendly pieces in a row. No Danger
							else dirBlockingPiece = new Vector2I(checkingQ,checkingR); // First piece found
						}
						else //Unfriendly Piece Found	
						{
							PIECES val = BBRef.GetPieceTypeFrom(index, !isWhiteTrn);
							if ( (val == PIECES.QUEEN) || (val == piece) )
							{
								if(dirBlockingPiece.X != HEX_BOARD_RADIUS+1 && dirBlockingPiece.Y != HEX_BOARD_RADIUS+1)
								{
									LegalMoves.Add(new Vector2I(checkingQ,checkingR));
									bp[dirBlockingPiece] = LegalMoves; // store blocking piece moves
								}
							}
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
	public void prepBlockingFrom(Vector2I cords)
	{
		blockingPieces = bbcheckForBlockingPiecesFrom(cords);
	}


	//
	private void fillRookCheckMoves(Vector2I kingCords, Vector2I moveToCords)
	{
		var deltaQ = kingCords.X - moveToCords.X;
		var deltaR = kingCords.Y - moveToCords.Y;
		var direction = new Vector2I(
			(deltaQ > 0) ? 1 : ( (deltaQ < 0) ? -1 : 0 ),
			(deltaR > 0) ? 1 : ( (deltaR < 0) ? -1 : 0 )
			);

		while( true )
		{
			GameInCheckMoves.Add(moveToCords);
			moveToCords.X += direction.X;
			moveToCords.Y += direction.Y;
			if( Bitboard128.IsLegalHexCords(moveToCords.X, moveToCords.Y) )
			{
				if(! BBRef.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y)))
					break;
			}
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
			if ( Bitboard128.IsLegalHexCords(moveToCords.X, moveToCords.Y) )
				if(! BBRef.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y))) break;
			else break;
		}
		return;
	}
	// SUB Routine
	public void fillInCheckMoves(PIECES pieceType, Vector2I cords, Vector2I kingCords, bool clear)
	{
		BoardRef.GameInCheckFrom = new Vector2I(cords.X, cords.Y);
		if (clear) GameInCheckMoves = new List<Vector2I> {};
		BoardRef.IsCheck = true;
		
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
				if( (cords.X == kingCords.X) || //same Q
					(cords.Y == kingCords.Y) || //same R
					(cords.X+cords.Y) == (kingCords.X+kingCords.Y) ) // same s
					fillRookCheckMoves(kingCords, cords);
				else
					fillBishopCheckMoves(kingCords, cords);
				break;
		}

		return;
	}
	

	//GEN
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> generateNextLegalMoves(Dictionary<PIECES, List<Vector2I>>[] AP)
	{
		int selfside = -1;
		if(BoardRef.IsWhiteTurn)
		{
			selfside = (int) SIDES.WHITE;
			ZeroBoard(WhiteAttackBoard);
		}
		else
		{
			selfside = (int) SIDES.BLACK;
			ZeroBoard(BlackAttackBoard);
		}

		myKingCords = AP[selfside][PIECES.KING][KING_INDEX];
		blockingPieces = bbcheckForBlockingPiecesFrom(myKingCords);
		
		lastInfluencedPieces = influencedPieces;
		influencedPieces = new Dictionary<Vector2I, List<Vector2I>> {};
			
		findLegalMovesFor(AP[selfside]);
		
		lastInfluencedPieces = null;
		
		return moves;
	}
	
}
}