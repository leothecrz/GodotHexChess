
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
	private readonly BoardState HexState;
	private readonly BitboardState Bitboards;


	//Testing
	public ulong startTime {get; private set;} = 0 ;
	public ulong stopTime {get; private set;} = 0;
	public double runningAVG {get; private set;} = 0;
	public int count {get; private set;} = -1;

	public int ATKMOD {get; set;} = 0;


	/// <summary>
	/// 
	/// </summary>
	/// <param name="bref"></param>
	/// <param name="bbref"></param>
	public HexMoveGenerator(ref BoardState bref, ref BitboardState bbref)
	{
		HexState = bref;
		Bitboards = bbref;
		resetState();
	}

	/// <summary>
	/// 
	/// </summary>
	public void resetState()
	{
		blockingPieces = new Dictionary<Vector2I, List<Vector2I>>(){};

		influencedPieces 		= new Dictionary<Vector2I, List<Vector2I>>(){};
		lastInfluencedPieces 	= new Dictionary<Vector2I, List<Vector2I>>(){}; 

		lastPinningPieces 	= new Dictionary<Vector2I, List<Vector2I>>(){};
		pinningPieces 		= new Dictionary<Vector2I, Vector2I>(){};

		GameInCheckMoves = new List<Vector2I>(){};

		WhiteAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
		BlackAttackBoard = createAttackBoard(HEX_BOARD_RADIUS);
		count = 0;
		ATKMOD = 0;
	}



	//Testing
	private void SetStartRunningAverage()
	{
		startTime = Time.GetTicksUsec();
		count += 1;
	}
	private void updateRunningAverage()
	{
		stopTime = Time.GetTicksUsec();
		if(count <= 0)
			return;
		double time = stopTime - startTime;
		runningAVG += ((time - runningAVG)/count);
	}

	public void printATK()
	{
		GD.Print("Black: ");
		PrettyPrintATKBOARD(BlackAttackBoard);
		GD.Print("White: ");
		PrettyPrintATKBOARD(WhiteAttackBoard);
	}

	

	private bool IsMyKingSafeFromSliding(Vector2I piece)
	{
		int index = QRToIndex(piece.X,piece.Y);
		if(Bitboards.IsPieceWhite(index) == HexState.IsWhiteTurn) return true;
		//List contains both friendly and non. must be filtered. returns zero.
		PIECES type = Bitboards.GetPieceTypeFrom(index, !HexState.IsWhiteTurn);
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
		Vector2I targetPos = new Vector2I(HexState.EnPassantCords.X, HexState.EnPassantCords.Y + ( HexState.IsWhiteTurn ? 1 : -1));
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
		
		if ( Bitboards.IsIndexEmpty(index) )
		{
			if( HexState.EnPassantCordsValid ) 
				if ( (HexState.EnPassantCords.X == qpos) && (HexState.EnPassantCords.Y == rpos) )
					if( EnPassantLegal() )
						moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		}
		else
		{
			if(Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn)
			{
				if ( HexState.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					moves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					moves[pawn][MOVE_TYPES.CAPTURE].Add(move);
			}
		}
		
		updateAttackBoard(qpos, rpos, ATKMOD, HexState.IsWhiteTurn); //make external
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
			if(Bitboards.IsIndexEmpty(index))
			{
				if ( HexState.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					moves[pawn][MOVE_TYPES.PROMOTE].Add(move);
				else
				{
					moves[pawn][MOVE_TYPES.MOVES].Add(move);
					boolCanGoFoward = true;
				}
			}
		}
		//Double Move From Start
		if( boolCanGoFoward && ( HexState.IsWhiteTurn ? isWhitePawnStart(pawn) : isBlackPawnStart(pawn) ) )
		{
			int doubleF = HexState.IsWhiteTurn ? pawn.Y - 2 : pawn.Y + 2;
			int index = QRToIndex(pawn.X, doubleF);
			if (Bitboards.IsIndexEmpty(index))
				moves[pawn][MOVE_TYPES.ENPASSANT].Add(new Vector2I(pawn.X, doubleF));
		}
		return;
	}
	private void findMovesForPawn(Vector2I pawn)
	{
		int fowardR = HexState.IsWhiteTurn ? pawn.Y - 1 : pawn.Y + 1;
		int leftCaptureR = HexState.IsWhiteTurn ? pawn.Y : pawn.Y + 1;
		int rightCaptureR = HexState.IsWhiteTurn? pawn.Y-1 : pawn.Y;

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
					updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);
					if (Bitboards.IsIndexEmpty(index)) 
						moves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
					else if(Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn)
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
				updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);
				if( Bitboards.IsIndexEmpty(index) )
					moves[rook][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos)) influencedPieces[pos].Add(rook);
					else influencedPieces[pos] = new List<Vector2I> {rook};
					
					if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn ) //Enemy
					{ 
						moves[rook][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if( Bitboards.GetPieceTypeFrom(index, !HexState.IsWhiteTurn) == PIECES.KING )
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if(Bitboard128.IsLegalHexCords(checkingQ, checkingR))
								updateAttackBoard(checkingQ, checkingR, 1, HexState.IsWhiteTurn);
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
				updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);
				if( Bitboards.IsIndexEmpty(index) )
					moves[bishop][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
				else
				{
					Vector2I pos = new Vector2I(checkingQ,checkingR);
					if(influencedPieces.ContainsKey(pos))
						influencedPieces[pos].Add(bishop);
					else
						influencedPieces[pos] = new List<Vector2I> {bishop};
					
					if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn ) // Enemy
					{
						moves[bishop][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
						//King Escape Fix
						if(Bitboards.GetPieceTypeFrom(index, !HexState.IsWhiteTurn) == PIECES.KING)
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
								updateAttackBoard(checkingQ, checkingR, 1 , HexState.IsWhiteTurn);
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

			updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);

			int index = QRToIndex(checkingQ,checkingR);

			if( Bitboards.IsIndexEmpty(index) )
			{
				moves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
			}
			else if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn )
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



	
	/// <summary>
	/// Fills the internal moves with the pseudo moves for all pieces given
	/// </summary>
	/// <param name="pieces"></param>
	// Internal Use // Only Call If Prep was manually done.
	public void findPseudoMovesFor(Dictionary<PIECES, List<Vector2I>> pieces)
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
				case PIECES.PAWN: 	findMovesForPawns(singleTypePieces); break;
				case PIECES.KNIGHT: findMovesForKnights(singleTypePieces); break;
				case PIECES.ROOK: 	findMovesForRooks(singleTypePieces); break;
				case PIECES.BISHOP: findMovesForBishops(singleTypePieces); break;
				case PIECES.QUEEN: 	findMovesForQueens(singleTypePieces); break;
				case PIECES.KING: 	findMovesForKings(singleTypePieces); break;
			}
		}
		updateRunningAverage();
		return;
	}


	


	// Attack Board




	//Based on the turn determine the appropriate board to update.
	private void updateAttackBoard(int q, int r, int mod, bool modw)
	{
		var atkbrd = modw ? WhiteAttackBoard : BlackAttackBoard;
		atkbrd[q][r] += mod;
		return;
	}
	//
	private void updateAtkBrbPawns(Vector2I cords, int mod)
	{
		//FIX
		var leftCaptureR = HexState.IsWhiteTurn ?  cords.Y : cords.Y + 1;
		var rightCaptureR = HexState.IsWhiteTurn ? cords.Y-1 : cords.Y;
		//Left Capture
		if( Bitboard128.IsLegalHexCords(cords.X-1, leftCaptureR) )
			updateAttackBoard(cords.X-1, leftCaptureR, mod, HexState.IsWhiteTurn);
		//Right Capture
		if( Bitboard128.IsLegalHexCords(cords.X+1, rightCaptureR) )
			updateAttackBoard(cords.X+1, rightCaptureR, mod, HexState.IsWhiteTurn);
		return;
	}
	//
	// public void modAtkBoard(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> moves, int mod)
	// {
	// 	foreach(KeyValuePair<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> movePair in moves)
	// 	{
	// 		if(movePair.Value.Keys.Count == 4) // PAWN
	// 			updateAtkBrbPawns(movePair.Key, mod);
	// 		else
	// 			foreach(KeyValuePair<MOVE_TYPES, List<Vector2I>> innerPair in movePair.Value)
	// 				foreach(Vector2I move in innerPair.Value)
	// 					updateAttackBoard(move.X, move.Y, mod, HexState.IsWhiteTurn);
	// 	}
	// }
	//
	public void rmvSelfAtks(Dictionary<PIECES, List<Vector2I>> lol) 
	{
		var savedMoves = moves;
		
		ATKMOD = -1;
		findPseudoMovesFor(lol);
	
		moves = savedMoves;
		return;
	}
	/// <summary>
	/// TO BE REPLACED
	/// SHOULD REMOVE ANY INFLUNCED AS WELL
	/// </summary>
	/// <param name="pieceType"></param>
	/// <param name="cords"></param>
	public void removeCapturedFromATBoard(PIECES pieceType, Vector2I cords)
	{
		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		var movedPiece = new Dictionary<PIECES, List<Vector2I>> { {pieceType, new List<Vector2I> {new Vector2I(cords.X, cords.Y)}} };
		rmvSelfAtks(movedPiece);
		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		return;
	}

	


	//Influence




	/// <summary>
	/// If pinner is in pinningPieces add the pinned piece to the acting piece's influence list.
	/// </summary>
	/// <param name="pinner"></param>
	/// <param name="acting"></param>
	public void pinningInfluenceCheck(Vector2I pinner, Vector2I acting)
	{
		if(!pinningPieces.ContainsKey(pinner))
			return;
		
		var pinned = pinningPieces[pinner];

		if(influencedPieces.ContainsKey(acting))
			influencedPieces[acting].Add(pinned);
		else
			influencedPieces[acting] = new(){pinned};
	}
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
				if(! Bitboards.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
				if(! Bitboards.IsIndexEmpty(QRToIndex(checking.X,checking.Y)))
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
	/// Create an ap list for the influenced pieces of the given cords. 
	/// </summary>
	/// <param name="type"></param>
	/// <param name="cords"></param>
	/// <param name="lastCords"></param>
	/// <returns></returns>
	public Dictionary<PIECES, List<Vector2I>> GetAPfromInfluenceOf(Vector2I lastCords)
	{
		//var internalDictionary = new Dictionary<PIECES, List<Vector2I>> {{type, new List<Vector2I>{cords}}};
		var internalDictionary = new Dictionary<PIECES, List<Vector2I>>(){};
		
		if (influencedPieces.ContainsKey(lastCords))
		{
			foreach( Vector2I item in influencedPieces[lastCords] )
			{
				var index = QRToIndex(item.X,item.Y);
				if (Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn) continue;
				var inPieceType = Bitboards.GetPieceTypeFrom(index, HexState.IsWhiteTurn);
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
			if(IsMyKingSafeFromSliding(pin.Value)) // TODO:: should also check that the line is not interupted
				goto toNext;

			List<Vector2I> path = GetAxialPath(myKingCords, pin.Value);
			path.Remove(pin.Value);
			foreach(Vector2I tile in path)
			{
				if(Bitboards.IsIndexEmpty(QRToIndex(tile.X, tile.Y)))
					continue;
				goto toNext;
			}
			lastPinningPieces[pin.Key] = blockingPieces[pin.Value]; //self in blocking pieces list adds n checks to interszection check
			lastPinningPieces[pin.Key].Add(pin.Value); // pinned can be index by length - 1
			toNext:;
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
			if( Bitboards.IsIndexEmpty(index) )
			{
				if(dirBlockingPiece.X != ILLEGAL_CORDS)
					LegalMoves.Add(new Vector2I(checkingQ,checkingR)); // Track legal moves for the blocking pieces
			}
			else
			{
				if( Bitboards.IsPieceWhite(index) == isWhiteTrn ) // Friend Piece
				{
					if(dirBlockingPiece.X != ILLEGAL_CORDS) break; // Two friendly pieces in a row. No Danger
					else dirBlockingPiece = new Vector2I(checkingQ,checkingR); // First piece found
				}
				else //Unfriendly Piece Found	
				{
					PIECES val = Bitboards.GetPieceTypeFrom(index, !isWhiteTrn);
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
		bool isW = Bitboards.IsPieceWhite(QRToIndex(cords.X,cords.Y));	
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
		var direction = GetRookVector(kingCords, moveToCords);
		if(direction == Vector2I.Zero) return;

		while( true )
		{
			GameInCheckMoves.Add(moveToCords);
			moveToCords.X += direction.X;
			moveToCords.Y += direction.Y;
			if( Bitboard128.IsLegalHexCords(moveToCords.X, moveToCords.Y) )
			{
				if(! Bitboards.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y)))
					break;
			}
			else
				break;
		}
		return;
	}
	private void fillBishopCheckMoves(Vector2I kingCords, Vector2I moveToCords)
	{

		var direction = GetBishopVector(kingCords, moveToCords);	
		if(direction == Vector2I.Zero) return;

		while( true )
		{
			GameInCheckMoves.Add(moveToCords);
			moveToCords.X += direction.X;
			moveToCords.Y += direction.Y;
			if ( Bitboard128.IsLegalHexCords(moveToCords.X, moveToCords.Y) )
				if(! Bitboards.IsIndexEmpty(QRToIndex(moveToCords.X, moveToCords.Y))) break;
			else break;
		}
		return;
	}
	public void fillInCheckMoves(PIECES pieceType, Vector2I cords, Vector2I kingCords)
	{
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


	private void filterKing()
	{
		if(!moves.ContainsKey(myKingCords))
			return;
		var enemyAtkBrd = HexState.IsWhiteTurn ? BlackAttackBoard : WhiteAttackBoard;
		foreach(MOVE_TYPES movetypes in moves[myKingCords].Keys)
			moves[myKingCords][movetypes].RemoveAll(move => enemyAtkBrd[move.X][move.Y] > 0);	
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
				var moveList = HexState.CheckByMany ? EmptyVector2IList : GameInCheckMoves;
				moves[valuePair.Key][innerValuePair.Key] = intersectOfTwoList(moveList , moves[valuePair.Key][innerValuePair.Key]);
			}
		}

		// unsure if necessary // influenced pieces would not allow an illegal capture???
		kingMoves[MOVE_TYPES.CAPTURE] = intersectOfTwoList(GameInCheckMoves, kingMoves[MOVE_TYPES.CAPTURE]);
		foreach( MOVE_TYPES moveType in kingMoves.Keys)
		{
			if(moveType == MOVE_TYPES.CAPTURE) continue;
			kingMoves[moveType] = differenceOfTwoList(kingMoves[moveType], GameInCheckMoves);
		}
		
	}
	public void filterLegalMoves()
	{	
		filterKing();
		if( HexState.IsCheck )
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


	/// <summary>
	/// Zero out the current turn's player attack board and generate moves for the same side's piece list.
	/// </summary>
	/// <param name="AP"></param>
	public void generateNextLegalMoves(Dictionary<PIECES, List<Vector2I>>[] AP)
	{
		int selfside = -1;
		if(HexState.IsWhiteTurn)
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
		
		ATKMOD = 1;
		findPseudoMovesFor(AP[selfside]);
		filterLegalMoves();

		//printATK();

		lastInfluencedPieces = null; //not necessary but explicit
		return;
	}
	

	/// <summary>
	/// Update the atk brd for the effects of 'cords' moving to 'moveto'
	/// </summary>
	/// <param name="pieceType"></param>
	/// <param name="cords"></param>
	/// <param name="moveTo"></param>
	public void generateMovesForPieceMove(PIECES pieceType, Vector2I cords, Vector2I moveTo, Vector2I myking)
	{
		myKingCords = myking;
		Dictionary<PIECES, List<Vector2I>> effectedPieces = GetAPfromInfluenceOf(cords);
		
		if (effectedPieces.ContainsKey(pieceType)) 
			effectedPieces[pieceType].Add(cords);
		else 
			effectedPieces[pieceType] = new(){cords};
		
		if(pinningPieces.ContainsKey(moveTo)) //capture pinning
		{
			var val = pinningPieces[moveTo];
			PIECES pinned = Bitboards.GetPieceTypeFrom(QRToIndex(val.X,val.Y), HexState.IsWhiteTurn);
			if (effectedPieces.ContainsKey(pinned)) 
				effectedPieces[pinned].Add(val);
			else 
				effectedPieces[pinned] = new(){val};
		}

		foreach(var bb in blockingPieces) // interrup pinning
		{
			if(!bb.Value.Contains(moveTo))
				continue;

			var val = bb.Key;
			PIECES pinned = Bitboards.GetPieceTypeFrom(QRToIndex(val.X,val.Y), HexState.IsWhiteTurn);
			if (effectedPieces.ContainsKey(pinned)) 
				effectedPieces[pinned].Add(val);
			else 
				effectedPieces[pinned] = new(){val};
		}

		foreach(var pieceList in effectedPieces)
		{
			if(PIECES.PAWN == pieceList.Key)
			{
				foreach(var pawn in pieceList.Value)
					updateAtkBrbPawns(pawn, -1);
				continue;
			}
			// NOT PAWNS
			foreach(var piece in pieceList.Value)
			{
				if(!moves.ContainsKey(piece))
					continue;
				foreach(var piecemoves in moves[piece].Values)
					foreach(var move in piecemoves)
						updateAttackBoard(move.X, move.Y, -1, HexState.IsWhiteTurn);
			}
		}
	
		effectedPieces[pieceType].RemoveAt(effectedPieces[pieceType].Count-1);
		effectedPieces[pieceType].Add(moveTo);
		
		prepBlockingFrom(myKingCords);

		//my king cords not set for filter
		ATKMOD = 1;
		findPseudoMovesFor(effectedPieces);
		filterLegalMoves();
		
		return;
	}


}
}