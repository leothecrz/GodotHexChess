
using System;
using System.Collections.Generic;
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
	public Dictionary<int, Dictionary<int,int>> WhiteAttackBoard {get; set;} // replace with bitboards
	public Dictionary<int, Dictionary<int,int>> BlackAttackBoard {get; set;} // replace with bitboards

	//PIECES
	private Dictionary<Vector2I, List<Vector2I>> lastInfluencedPieces {get; set;}
	public Dictionary<Vector2I, List<Vector2I>> influencedPieces {get; set;}
	
	//BLOCKING
	public Dictionary<Vector2I, List<Vector2I>> blockingPieces {get; set;}

	public Dictionary<Vector2I, List<Vector2I>>  lastPinningPieces {get; set;}	
	public Dictionary<Vector2I, Vector2I>  pinningPieces {get; set;}

	//CHECK
	public List<Vector2I> GameInCheckMoves {get; set;}

	//KING
	private Vector2I myKingCords;


	//REFS
	private readonly BoardState BoardRef;
	private readonly BitboardState BitState;


	//Testing
	public ulong startTime {get; private set;} = 0 ;
	public ulong stopTime {get; private set;} = 0;
	public double runningAVG {get; private set;} = 0;
	public int count {get; private set;} = -1;


	public HexMoveGenerator(ref BoardState bref, ref BitboardState bbref)
	{
		BoardRef = bref;
		BitState = bbref;
		
		blockingPieces = new Dictionary<Vector2I, List<Vector2I>>(){};

		influencedPieces 		= new Dictionary<Vector2I, List<Vector2I>>(){};
		lastInfluencedPieces 	= new Dictionary<Vector2I, List<Vector2I>>(){}; 

		lastPinningPieces 	= new Dictionary<Vector2I, List<Vector2I>>(){};
		pinningPieces 		= new Dictionary<Vector2I, Vector2I>(){};

		GameInCheckMoves = new List<Vector2I>(){};

		WhiteAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
		BlackAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
	}


	//Testing
	private void SetStartRunningAverage()
	{
		startTime = Time.GetTicksUsec();
	}
	private void updateRunningAverage()
	{
		stopTime = Time.GetTicksUsec();
		if(count <= 0)
			return;
		double time = stopTime - startTime;
		runningAVG += ((time - runningAVG)/count);
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


	private bool IsMyKingSafeFromSliding(Vector2I piece)
	{
		int index = QRToIndex(piece.X,piece.Y);
		if(BitState.IsPieceWhite(index) == BoardRef.IsWhiteTurn) return true;
		//List contains both friendly and non. must be filtered. returns zero.
		PIECES type = BitState.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn);
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
		return true;
	}


	// Pawn Moves
	public bool EnPassantLegal()
	{
		Vector2I targetPos = new Vector2I(BoardRef.EnPassantCords.X, BoardRef.EnPassantCords.Y + ( BoardRef.IsWhiteTurn ? 1 : -1));
		if(lastInfluencedPieces.ContainsKey(targetPos))
			foreach( Vector2I piece in lastInfluencedPieces[targetPos])
			{
				if(!IsMyKingSafeFromSliding(piece))
					return false;
			}
		return true;
	}
	private void findCaptureMovesForPawn(Vector2I pawn, int qpos, int rpos)
	{
		if ( ! Bitboard128.IsLegalHexCords(qpos, rpos) ) return;
			
		Vector2I move = new Vector2I(qpos, rpos);
		int index = QRToIndex(qpos,rpos);
		
		if ( BitState.IsIndexEmpty(index) )
		{
			if( BoardRef.EnPassantCordsValid ) 
				if ( (BoardRef.EnPassantCords.X == qpos) && (BoardRef.EnPassantCords.Y == rpos) )
					if( EnPassantLegal() )
						moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		}
		else
		{
			if(BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn)
			{
				if ( BoardRef.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					moves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
			}
		}
		
		updateAttackBoard(qpos, rpos, 1, BoardRef.IsWhiteTurn);
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
			if(BitState.IsIndexEmpty(index))
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
			if (BitState.IsIndexEmpty(index))
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

	}
	private void findMovesForPawns(List<Vector2I> PawnArray)
	{
		foreach ( Vector2I pawn in PawnArray)
			findMovesForPawn(pawn);
		return;
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
					if (BitState.IsIndexEmpty(index)) 
						moves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
					else if(BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn)
						moves[knight][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ,checkingR));
				}
			}
			invertAt2Counter += 1;
		}
		
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
				if( BitState.IsIndexEmpty(index) )
					moves[rook][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos)) influencedPieces[pos].Add(rook);
					else influencedPieces[pos] = new List<Vector2I> {rook};
					
					if( BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn ) //Enemy
					{ 
						moves[rook][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if( BitState.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn) == PIECES.KING )
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
				if( BitState.IsIndexEmpty(index) )
					moves[bishop][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos))
						influencedPieces[pos].Add(bishop);
					else
						influencedPieces[pos] = new List<Vector2I> {bishop};
					
					if( BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn ) // Enemy
					{
						moves[bishop][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if(BitState.GetPieceTypeFrom(index, !BoardRef.IsWhiteTurn) == PIECES.KING)
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
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> tempMoves = new(){};
		
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

			if( BitState.IsIndexEmpty(index) )
			{
				moves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
			}
			else if( BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn )
				moves[king][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
			
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
		SetStartRunningAverage();
		moves = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>>();

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
		
		updateRunningAverage();
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


	/// <summary>
	/// Track any pieces along any BISHOP or ROOK vector from the given cords.
	/// </summary>
	/// <param name="cords"></param>
	public void addInflunceFrom(Vector2I cords)
	{
		foreach( Vector2I v in ROOK_VECTORS.Values)
		{
			var checking = new Vector2I(cords.X,cords.Y) + v;
			while (Bitboard128.IsLegalHexCords(checking.X, checking.Y))
			{
				if(! BitState.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
				if(! BitState.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
	/// <summary>
	/// Create an AP list for the piece that was moved. Add influenced pieces to the AP list.
	/// </summary>
	/// <param name="type"></param>
	/// <param name="cords"></param>
	/// <param name="lastCords"></param>
	/// <returns></returns>
	public Dictionary<PIECES, List<Vector2I>> setupActiveForSingle(PIECES type, Vector2I cords, Vector2I lastCords)
	{
		var internalDictionary = new Dictionary<PIECES, List<Vector2I>> {{type, new List<Vector2I>{cords}}};
		
		if (influencedPieces.ContainsKey(lastCords))
		{
			foreach( Vector2I item in influencedPieces[lastCords] )
			{
				var index = QRToIndex(item.X,item.Y);
				if (BitState.IsPieceWhite(index) != BoardRef.IsWhiteTurn) continue;
				var inPieceType = BitState.GetPieceTypeFrom(index, BoardRef.IsWhiteTurn);
				if ( internalDictionary.ContainsKey(inPieceType) )
					internalDictionary[inPieceType].Add(item);
				else
					internalDictionary[inPieceType] = new List<Vector2I> { item };
			}
		}
		return internalDictionary;
	}


	//
	private void prepPinning()
	{
		lastPinningPieces = new(){};
		foreach(var pin in pinningPieces)
		{
			if(IsMyKingSafeFromSliding(pin.Value))
				continue;
			
			lastPinningPieces[pin.Key] = blockingPieces[pin.Value];
			lastPinningPieces[pin.Key].Add(pin.Value);
		}
	}
	//Blocking
	private void CheckForBlockOn(Vector2I activeVector, Vector2I cords, PIECES piece, bool isWhiteTrn)
	{
		List<Vector2I> LegalMoves = new(){};
		Vector2I dirBlockingPiece = new(ILLEGAL_CORDS, 0);
		
		int checkingQ = cords.X + activeVector.X;
		int checkingR = cords.Y + activeVector.Y;
		
		while ( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
		{
			int index = QRToIndex(checkingQ,checkingR);
			if( BitState.IsIndexEmpty(index) )
			{
				if(dirBlockingPiece.X != ILLEGAL_CORDS)
					LegalMoves.Add(new Vector2I(checkingQ,checkingR)); // Track legal moves for the blocking pieces
			}
			else
			{
				if( BitState.IsPieceWhite(index) == isWhiteTrn ) // Friend Piece
				{
					if(dirBlockingPiece.X != ILLEGAL_CORDS) break; // Two friendly pieces in a row. No Danger
					else dirBlockingPiece = new Vector2I(checkingQ,checkingR); // First piece found
				}
				else //Unfriendly Piece Found	
				{
					PIECES val = BitState.GetPieceTypeFrom(index, !isWhiteTrn);
					if ( (val == piece) || (val == PIECES.QUEEN) )
					{
						if(dirBlockingPiece.X != ILLEGAL_CORDS)
						{
							LegalMoves.Add(new Vector2I(checkingQ,checkingR));
							blockingPieces[dirBlockingPiece] = LegalMoves; // store blocking piece moves
							pinningPieces[new Vector2I(checkingQ, checkingR)] = dirBlockingPiece;
						}
					}
					break;
				}
			}

			checkingQ += activeVector.X;
			checkingR += activeVector.Y;
		}
	}
	// Check if the current cordinates are being protected by a friendly piece from the enemy sliding pieces.
	private void CheckBlockOnVectorList(Vector2I cords, PIECES piece, Dictionary<string,Vector2I> dirSet)
	{
		bool isW = BitState.IsPieceWhite(QRToIndex(cords.X,cords.Y));	
		foreach( Vector2I direction in dirSet.Values )
			CheckForBlockOn(direction, cords, piece, isW);
		return;
	}
	public void prepBlockingFrom(Vector2I cords)
	{
		prepPinning();
		blockingPieces = new Dictionary<Vector2I, List<Vector2I>>(){};
		pinningPieces = new Dictionary<Vector2I, Vector2I>(){};
		CheckBlockOnVectorList(cords, PIECES.ROOK, ROOK_VECTORS);
		CheckBlockOnVectorList(cords, PIECES.BISHOP, BISHOP_VECTORS);
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
				if(! BitState.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y)))
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
				if(! BitState.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y))) break;
			else break;
		}
		return;
	}
	public void fillInCheckMoves(PIECES pieceType, Vector2I cords, Vector2I kingCords, bool clear)
	{
		BoardRef.GameInCheckFrom = new Vector2I(cords.X, cords.Y); //make external
		if (clear) GameInCheckMoves = new List<Vector2I> {};
		BoardRef.IsCheck = true; // maker external
		
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


	private void filterPins()
	{
		foreach(var pin in lastPinningPieces)
		{
			if(!moves.ContainsKey(pin.Key))
				continue;
			foreach(var types in moves[pin.Key].Keys)
				moves[pin.Key][types] = intersectOfTwoList(pin.Value,moves[pin.Key][types]);
		}
	}
	private void filterBlocking()
	{
		foreach(var piece in blockingPieces)
		{
			if(!moves.ContainsKey(piece.Key))
				continue;
			
			foreach( MOVE_TYPES moveType in moves[piece.Key].Keys)
				moves[piece.Key][moveType] = intersectOfTwoList(piece.Value, moves[piece.Key][moveType]);
		}
	}
	private void filterForInCheck(ref Dictionary<MOVE_TYPES, List<Vector2I>> kingMoves)
	{
		foreach(var valuePair in moves)
		{
			foreach(var innerValuePair in valuePair.Value)
			{
				var moveList = BoardRef.CheckByMany ? EmptyVector2IList : GameInCheckMoves;
				moves[valuePair.Key][innerValuePair.Key] = intersectOfTwoList(moveList , moves[valuePair.Key][innerValuePair.Key]);
			}
		}

		// unsure if necessary // influenced pieces would not allow an illegal capture???
		//moves[king][MOVE_TYPES.CAPTURE] = intersectOfTwoList(GameInCheckMoves, moves[king][MOVE_TYPES.CAPTURE]);
		foreach( MOVE_TYPES moveType in kingMoves.Keys)
		{
			if(moveType == MOVE_TYPES.CAPTURE) continue;
			kingMoves[moveType] = differenceOfTwoList(kingMoves[moveType], GameInCheckMoves);
		}
		
	}
	public void filterLegalMoves()
	{	
		if( BoardRef.IsCheck )
		{
			// King moves are handled differently than all the rest.
			Dictionary<MOVE_TYPES, List<Vector2I>> kingMoves = moves[myKingCords];
			moves.Remove(myKingCords);
			filterForInCheck(ref kingMoves);
			moves[myKingCords] = kingMoves;
		}
		if( blockingPieces.Count > 0)
			filterBlocking();
		if( lastPinningPieces.Count > 0)
			filterPins();
		
		return;
	}


	//GEN
	public void generateNextLegalMoves(Dictionary<PIECES, List<Vector2I>>[] AP)
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

		prepBlockingFrom(myKingCords);

		lastInfluencedPieces = influencedPieces;
		influencedPieces = new Dictionary<Vector2I, List<Vector2I>> {};		
		
		findLegalMovesFor(AP[selfside]); 
		filterLegalMoves();

		lastInfluencedPieces = null;
		
		return;
	}
	

}
}