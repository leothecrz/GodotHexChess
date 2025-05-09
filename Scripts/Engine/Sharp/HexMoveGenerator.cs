
using System.Collections.Generic;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{

//TODO :: Offload onto GPU?

public class HexMoveGenerator
{
	//MOVE DICT
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> unfilteredMoves {get; set;}
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> filteredMoves {get; set;}


	//ATK
	public Dictionary<int, Dictionary<int,int>> WhiteAttackBoard {get; set;} // replace with bitboards
	public Dictionary<int, Dictionary<int,int>> BlackAttackBoard {get; set;} // replace with bitboards



	//INFLUENCE
	/// <summary>
	/// 
	/// </summary>
	private Dictionary<Vector2I, List<Vector2I>> lastInfluencedPieces {get; set;}
	/// <summary>
	/// 
	/// </summary>
	public Dictionary<Vector2I, List<Vector2I>> influencedPieces {get; set;}
	
	//BLOCKING
	/// <summary>
	/// 
	/// </summary>
	public Dictionary<Vector2I, List<Vector2I>> blockingPieces {get; set;}

	//PINNING
	/// <summary>
	/// 
	/// </summary>
	public Dictionary<Vector2I, List<Vector2I>>  lastPinningPieces {get; set;}	
	/// <summary>
	/// 
	/// </summary>
	public Dictionary<Vector2I, Vector2I>  pinningPieces {get; set;}

	//PROTECTED
	public Dictionary<Vector2I, List<Vector2I>> protectedPieces {get; set;}


	//CHECK
	/// <summary>
	/// 
	/// </summary>
	public List<Vector2I> GameInCheckMoves {get; set;}

	//KING
	/// <summary>
	/// 
	/// </summary>
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

		WhiteAttackBoard = CreateQRDictionary(HEX_BOARD_RADIUS);
		BlackAttackBoard = CreateQRDictionary(HEX_BOARD_RADIUS);
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
						unfilteredMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
		}
		else
		{
			if(Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn)
			{
				if ( HexState.IsWhiteTurn ? isWhitePawnPromotion(move) : isBlackPawnPromotion(move) ) 
					unfilteredMoves[pawn][MOVE_TYPES.PROMOTE].Add(move); // PROMOTE CAPTURE
				else
					unfilteredMoves[pawn][MOVE_TYPES.CAPTURE].Add(move);
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
					unfilteredMoves[pawn][MOVE_TYPES.PROMOTE].Add(move);
				else
				{
					unfilteredMoves[pawn][MOVE_TYPES.MOVES].Add(move);
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
				unfilteredMoves[pawn][MOVE_TYPES.ENPASSANT].Add(new Vector2I(pawn.X, doubleF));
		}
		return;
	}
	private void findMovesForPawn(Vector2I pawn)
	{
		int fowardR = HexState.IsWhiteTurn ? pawn.Y - 1 : pawn.Y + 1;
		int leftCaptureR = HexState.IsWhiteTurn ? pawn.Y : pawn.Y + 1;
		int rightCaptureR = HexState.IsWhiteTurn? pawn.Y-1 : pawn.Y;

		unfilteredMoves[pawn] = DeepCopyMoveTemplate(PAWN_MOVE_TEMPLATE);

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
		unfilteredMoves[knight] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
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
						unfilteredMoves[knight][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ,checkingR));
					else if(Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn)
						unfilteredMoves[knight][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ,checkingR));
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
		unfilteredMoves[rook] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
		foreach(string dir in ROOK_VECTORS.Keys)
		{
			Vector2I activeVector = ROOK_VECTORS[dir];
			int checkingQ = rook.X + activeVector.X;
			int checkingR = rook.Y + activeVector.Y;
			while (Bitboard128.IsLegalHexCords(checkingQ,checkingR))
			{
				var index = QRToIndex(checkingQ,checkingR);
				updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);
				if( !Bitboards.IsIndexEmpty(index) )
				{
					Vector2I pos = new(checkingQ,checkingR);
					influenceAddCheck(pos, rook);									
					if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn ) //Enemy
					{ 
						unfilteredMoves[rook][MOVE_TYPES.CAPTURE].Add(new(checkingQ, checkingR));
						//King Escape Fix
						if( Bitboards.GetPieceTypeFrom(index, !HexState.IsWhiteTurn) == PIECES.KING )
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if(Bitboard128.IsLegalHexCords(checkingQ, checkingR))
								updateAttackBoard(checkingQ, checkingR, 1, HexState.IsWhiteTurn);
						}
					}
					else
					{
						protectingAddCheck(rook, new(checkingQ, checkingR));
					}
					break;
				}
				unfilteredMoves[rook][MOVE_TYPES.MOVES].Add(new(checkingQ, checkingR));
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
		unfilteredMoves[bishop] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);
		foreach( string dir in BISHOP_VECTORS.Keys )
		{
			Vector2I activeVector = BISHOP_VECTORS[dir];
			int checkingQ = bishop.X + activeVector.X;
			int checkingR = bishop.Y + activeVector.Y;
			while ( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
			{
				var index = QRToIndex(checkingQ,checkingR);
				updateAttackBoard(checkingQ, checkingR, ATKMOD, HexState.IsWhiteTurn);
				if( !Bitboards.IsIndexEmpty(index) )
				{
					Vector2I pos = new(checkingQ,checkingR);
					influenceAddCheck(pos, bishop);
					if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn ) // Enemy
					{
						unfilteredMoves[bishop][MOVE_TYPES.CAPTURE].Add(new(checkingQ, checkingR));
						//King Escape Fix
						if(Bitboards.GetPieceTypeFrom(index, !HexState.IsWhiteTurn) == PIECES.KING)
						{
							checkingQ += activeVector.X;
							checkingR += activeVector.Y;
							if( Bitboard128.IsLegalHexCords(checkingQ,checkingR) )
								updateAttackBoard(checkingQ, checkingR, 1 , HexState.IsWhiteTurn);
						}
					}
					else
					{
						protectingAddCheck(bishop, new(checkingQ, checkingR));
					}
					break;
				}
				unfilteredMoves[bishop][MOVE_TYPES.MOVES].Add(new(checkingQ, checkingR));
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
			tempMoves[queen] =  DeepCopyInnerDictionary(unfilteredMoves, queen);

		findMovesForBishops(QueenArray);
		foreach( Vector2I queen in QueenArray)
			foreach( MOVE_TYPES moveType in tempMoves[queen].Keys)
				foreach( Vector2I move in tempMoves[queen][moveType])
					unfilteredMoves[queen][moveType].Add(move);

		return;
	}
	
	
	// King Moves
	private void findMovesForKing(Vector2I king)
	{
		unfilteredMoves[king] = DeepCopyMoveTemplate(DEFAULT_MOVE_TEMPLATE);

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
				unfilteredMoves[king][MOVE_TYPES.MOVES].Add(new Vector2I(checkingQ, checkingR));
			}
			else if( Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn )
				unfilteredMoves[king][MOVE_TYPES.CAPTURE].Add(new Vector2I(checkingQ, checkingR));
			
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
		unfilteredMoves = new(){};
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




	/// <summary>
	/// Update the indicated attack board position on the selected side by the given ammount.
	/// </summary>
	/// <param name="q"> Q Cord</param>
	/// <param name="r"> R Cord</param>
	/// <param name="mod"> update amount</param>
	/// <param name="modw"> modify White? else Black.</param>
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
		
		var savedMoves = filteredMoves;
		var influence = influencedPieces;
		var pin = pinningPieces;

		influencedPieces = new();
		pinningPieces = new();
		
		ATKMOD = -1;
		findPseudoMovesFor(movedPiece);
	
		filteredMoves = savedMoves;
		influencedPieces = influence;
		pinningPieces = pin;

		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		return;
	}

	


	//Influence

	/// <summary>
	/// 
	/// </summary>
	/// <param name="position"></param>
	/// <param name="piece"></param>
	public void protectingAddCheck(Vector2I position, Vector2I piece)
	{
		if(protectedPieces.ContainsKey(position))
		{ 
			protectedPieces[position].Add(piece);
			return;
		}
		protectedPieces[position] = new () {piece};
		return;
	}
	/// <summary>
	/// 
	/// </summary>
	/// <param name="position"></param>
	/// <param name="piece"></param>
	public void influenceAddCheck(Vector2I position, Vector2I piece)
	{
		if(influencedPieces.ContainsKey(position))
		{ 
			influencedPieces[position].Add(piece);
			return;
		}
		influencedPieces[position] = new () {piece};
		return;
	}
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
		
		if(pinned == acting)
			return;

		if(influencedPieces.ContainsKey(acting))
			if(!influencedPieces[acting].Contains(pinned))
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
		var internalDictionary = new Dictionary<PIECES, List<Vector2I>>(){};
		
		if (!influencedPieces.ContainsKey(lastCords))
			return internalDictionary;

		foreach( Vector2I item in influencedPieces[lastCords] )
		{
			var index = QRToIndex(item.X,item.Y);
			
			if (Bitboards.IsPieceWhite(index) != HexState.IsWhiteTurn) 
				continue;
			
			var inPieceType = Bitboards.GetPieceTypeFrom(index, HexState.IsWhiteTurn);
			if ( internalDictionary.ContainsKey(inPieceType) )
				internalDictionary[inPieceType].Add(item);
			else
				internalDictionary[inPieceType] = new List<Vector2I> { item };
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
	//
	public void prepBlockingFrom(Vector2I cords)
	{
		prepPinning();
		pinningPieces = new() {};
		blockingPieces = new() {};
		protectedPieces = new() {};
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
		if(!filteredMoves.ContainsKey(myKingCords))
			return;
		var enemyAtkBrd = HexState.IsWhiteTurn ? BlackAttackBoard : WhiteAttackBoard;
		foreach(MOVE_TYPES movetypes in filteredMoves[myKingCords].Keys)
			filteredMoves[myKingCords][movetypes].RemoveAll(move => enemyAtkBrd[move.X][move.Y] > 0);	
	}
	private void filterPins()
	{
		foreach(var pin in lastPinningPieces)
		{
			if(!filteredMoves.ContainsKey(pin.Key))
				continue;
			foreach(var types in filteredMoves[pin.Key].Keys)
				filteredMoves[pin.Key][types] = intersectOfTwoList(pin.Value,filteredMoves[pin.Key][types]);
		}
	}
	private void filterBlocking()
	{
		foreach(var piece in blockingPieces)
		{
			if(!filteredMoves.ContainsKey(piece.Key))
				continue;
			
			foreach( MOVE_TYPES moveType in filteredMoves[piece.Key].Keys)
				filteredMoves[piece.Key][moveType] = intersectOfTwoList(piece.Value, filteredMoves[piece.Key][moveType]);
		}
	}
	private void filterForInCheck(ref Dictionary<MOVE_TYPES, List<Vector2I>> kingMoves)
	{
		foreach(var valuePair in filteredMoves)
		{
			foreach(var innerValuePair in valuePair.Value)
			{
				var moveList = HexState.CheckByMany ? EmptyVector2IList : GameInCheckMoves;
				filteredMoves[valuePair.Key][innerValuePair.Key] = intersectOfTwoList(moveList , filteredMoves[valuePair.Key][innerValuePair.Key]);
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
		
		filteredMoves = DeepCopyLegalMoves(unfilteredMoves);

		filterKing();
		if( HexState.IsCheck )
		{
			// King moves are handled differently than all the rest.
			Dictionary<MOVE_TYPES, List<Vector2I>> kingMoves = filteredMoves[myKingCords];
			filteredMoves.Remove(myKingCords);
			filterForInCheck(ref kingMoves);
			filteredMoves[myKingCords] = kingMoves;
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
		int selfside;
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

		ATKMOD = 1;
		lastInfluencedPieces = influencedPieces;
		influencedPieces = new Dictionary<Vector2I, List<Vector2I>> () {};
		findPseudoMovesFor(AP[selfside]);
		filterLegalMoves();
		lastInfluencedPieces = null; //not necessary but explicit
		return;
	}
	
	
	private void fillEffectWithPinAndBlock(Vector2I cords, Vector2I moveTo, Dictionary<PIECES, List<Vector2I>> effectedPieces)
	{
		if(pinningPieces.ContainsKey(moveTo)) //captured a pinning piece
		{
			var val = pinningPieces[moveTo];
			PIECES pinned = Bitboards.GetPieceTypeFrom(QRToIndex(val.X,val.Y), HexState.IsWhiteTurn);
			if(val != cords)
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
			if(pinned == PIECES.ZERO)
				continue;
			
			if (effectedPieces.ContainsKey(pinned))
				if(!effectedPieces[pinned].Contains(val)) 
					effectedPieces[pinned].Add(val);
			else 
				effectedPieces[pinned] = new(){val};
		}
	}
	private void nonPawnUpdate(KeyValuePair<PIECES, List<Vector2I>> pieceList)
	{
		if(PIECES.QUEEN == pieceList.Key || PIECES.ROOK == pieceList.Key || PIECES.BISHOP == pieceList.Key) //SLIDING PROTECTION CLEARED
		{
			foreach(var piece in pieceList.Value)
			{
				if(!protectedPieces.ContainsKey(piece)) continue;
				var protectedList = protectedPieces[piece];
				foreach(var protectedPiece in protectedList)//King can't move onto its own pieces.
				{
					if(Bitboards.IsPieceWhite(QRToIndex(protectedPiece)) != HexState.IsWhiteTurn) continue;
					updateAttackBoard(protectedPiece.X, protectedPiece.Y, -1, HexState.IsWhiteTurn);
				}
			}
		}
		foreach(var piece in pieceList.Value) // CLEAN UP ALL NON-PAWN
		{
			//var activeMoves = HexState.IsCheck ? unfilteredMoves : filteredMoves
			if(!unfilteredMoves.ContainsKey(piece))
				continue;
			foreach(var piecemoves in unfilteredMoves[piece].Values)
			//foreach(var piecemoves in filteredMoves[piece].Values)
				foreach(var move in piecemoves)
					updateAttackBoard(move.X, move.Y, -1, HexState.IsWhiteTurn);
		}
	}
	private void updateATKfromEffectList(Dictionary<PIECES, List<Vector2I>> effectedPieces)
	{
		foreach(var pieceList in effectedPieces)
		{
			if(PIECES.PAWN == pieceList.Key)
			{
				foreach(var pawn in pieceList.Value)
					updateAtkBrbPawns(pawn, -1);
				continue;
			}
			nonPawnUpdate(pieceList);
		}
	}
	/// <summary>
	/// Update the atk board for the effects of 'cords' moving to 'moveto'
	/// 
	/// (WIP) remove previous effects on attackboard.
	/// recalculing moves.
	/// AP INFLUENCE has zero as key. ERROR 
	/// </summary>
	/// <param name="pieceType"></param>
	/// <param name="cords"></param>
	/// <param name="moveTo"></param>
	public void generateMovesForPieceMove(PIECES pieceType, Vector2I cords, Vector2I moveTo, Vector2I myking)
	{
		Dictionary<PIECES, List<Vector2I>> effectedPieces = GetAPfromInfluenceOf(cords); // zero hold pos of moving piece
		fillEffectWithPinAndBlock(cords, moveTo, effectedPieces);
		if (effectedPieces.ContainsKey(pieceType)) //Add self to effected list
			effectedPieces[pieceType].Add(cords);
		else 
			effectedPieces[pieceType] = new(){cords};
		
		updateATKfromEffectList(effectedPieces);

		//remove old self and add new position 
		effectedPieces[pieceType].RemoveAt(effectedPieces[pieceType].Count-1);
		effectedPieces[pieceType].Add(moveTo);
		
		myKingCords = myking;
		prepBlockingFrom(myKingCords);

		//my king cords not set for filter
		ATKMOD = 1;
		findPseudoMovesFor(effectedPieces);
		filterLegalMoves();
		return;
	}


}
}