using Godot;

using System;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;

using HexChess;
using static HexChess.HexConst;
using static HexChess.FENConst;

[GlobalClass]
public partial class HexEngineSharp : Node
{
	// State Holders
	private readonly BoardState HexState;
	private readonly BitboardState BitBoards;
	private readonly EnemyState Enemy;
	private readonly HexMoveGenerator mGen;

	// Internal
	private Stack<HistEntry> historyStack; // HISTORY
	/// <summary>
	/// MOVE AUTHORITY - locks the MakeMove API when an AI opponent is set and it is its turn.
	/// </summary>
	private bool moveLock;


	/// <summary>
	/// Constructor. (or) When node is initiated. Initiates state holders and the move generator.
	/// HexEngineSharp is the master cordinator of the engine module.
	/// </summary>
	public HexEngineSharp()
	{
		HexState = new BoardState();
		BitBoards = new BitboardState();
		Enemy = new EnemyState();
		mGen = new HexMoveGenerator(ref HexState,ref BitBoards);
		historyStack = null;
		moveLock = true;
	}


	//Utility 


	/// <summary>
	/// Retrives the position of both kings based on the current turn.  
	/// </summary>
	/// <param name="myking"> The position of the king belonging to the current turn's side.</param>
	/// <param name="theirKing"> Opposing king </param>
	private void GetKings(out Vector2I myking, out Vector2I theirKing)
	{
		myking = BitBoards.ActivePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
		theirKing = BitBoards.ActivePieces[(int)(HexState.IsWhiteTurn ?  SIDES.BLACK : SIDES.WHITE)][PIECES.KING][KING_INDEX];
	}



	//Init



	/// <summary>
	/// Fill The Board by translating a fen string. Set the board state. DOES NOT VERIFY FEN STRING FOR ILLEGAL POSITIONS -- (W I P)
	/// </summary>
	/// <param name="fenString"> a string in the fasion of "////////// w/b EnPassant Turn#" to describe the board state. </param>
	/// <returns></returns>
	private bool fillBoardwithFEN(string fenString)
	{
		string [] fenSections =  fenString.Split(' ');
		if (fenSections.Length != 4)
		{
			GD.PushError("Not Enough FEN Sections");
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
			GD.PushError("Regex fail - illegal characters in the FEN STRING");
			return false;
		}
		if( result.Value != fenSections[0] )
		{
			GD.PushError( $"{result.Value} {fenString} Invalid Board Description");
			return false;
		}
	
		BitBoards.InitiateStateBitboards();
		for(int q=-HEX_BOARD_RADIUS; q <= HEX_BOARD_RADIUS; q+=1)
		{
			int mappedQ = q + HEX_BOARD_RADIUS;
			string activeRow = BoardColumns[mappedQ];
			
			int r1 = Math.Max(-HEX_BOARD_RADIUS, -q-HEX_BOARD_RADIUS);
			int r2 = Math.Min(HEX_BOARD_RADIUS, -q+HEX_BOARD_RADIUS);

			for(int i=0; i < activeRow.Length; i += 1 )
			{
				char activeChar = activeRow[i];
				if( IsCharInt(activeChar) )
				{
					int pushDistance = (int) activeChar - '0';
					while ( (i+1 < activeRow.Length) && IsCharInt(activeRow[i+1]))
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
						BitBoards.AddFromCharTo(activeChar,q,r1);
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
		BitBoards.GenerateCombinedStateBitboards();
		
		//Is White Turn
		if(fenSections[1] == "w")
			HexState.IsWhiteTurn = true;
		else if (fenSections[1] == "b")
			HexState.IsWhiteTurn = false;
		else
		{
			GD.PushError("Regex fail");
			return false;
		}

		//EnPassant Cords
		if(fenSections[2] != "-")
		{
			HexState.EnPassantCords = new (HexState.EnPassantTarget.X, HexState.EnPassantTarget.Y + (HexState.IsWhiteTurn ? -1 : 1));
			HexState.EnPassantTarget = DecodeFEN(fenSections[2]);
			HexState.EnPassantCordsValid = true;
		}
		else
		{
			HexState.EnPassantCords = new (ILLEGAL_CORDS,0);
			HexState.EnPassantTarget = new (ILLEGAL_CORDS,0);
			HexState.EnPassantCordsValid = false;
		}
		
		// Turn Number
		try {HexState.TurnNumber = fenSections[3].ToInt();}
		catch(Exception e)
		{
			GD.PrintErr(e);
			return false;
		}
		if(HexState.TurnNumber < 1)
			HexState.TurnNumber = 1;
			
		if(BitBoards.BoardEmpty())
		{
			GD.PushError("Empty Board");
			return false;
		}

		return true;
	}
	/// <summary>
	/// If the opponent is set to be ai, initiate a new agent instance.
	/// </summary>
	private void initiateEngineAI()
	{
		if(!Enemy.EnemyIsAI)
			return;
			
		switch (Enemy.EnemyType)
		{
			case ENEMY_TYPES.RANDOM:
				Enemy.EnemyAI = new RandomAI(Enemy.EnemyPlaysWhite);
				break;
			case ENEMY_TYPES.NN:
				GD.PushWarning("NN Agent not yet implemented, using RNG");
				Enemy.EnemyAI = new RandomAI(Enemy.EnemyPlaysWhite);
				break;
			case ENEMY_TYPES.MIN_MAX:
				Enemy.EnemyAI = new MinMaxAI(Enemy.EnemyPlaysWhite, Enemy.EnemyDifficulty > 0 ? Enemy.EnemyDifficulty : 1);
				break;
		}
		return;
	}
	

	
	/// <summary>
	/// Generate the attack board of the opposing player. Determine if in check.
	/// </summary>
	private void fillOpAtkBrd()
	{
		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		fillAtkBrd();
		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
	}
	/// <summary>
	/// Generate moves of the the current turn and fill in incheck moves if opposing king is in check.
	/// </summary>
	private void fillAtkBrd()
	{
		GetKings(out Vector2I _, out Vector2I kingCords);
		mGen.generateNextLegalMoves(BitBoards.ActivePieces);
		if(!IsUnderAttack(kingCords, mGen.filteredMoves, out List<Vector2I> from))
			return;
		
		HexState.IsCheck = true;
		HexState.CheckByMany = from.Count > 1;
		mGen.GameInCheckMoves = new();

		foreach(Vector2I atk in from)
			mGen.fillInCheckMoves(BitBoards.GetPieceTypeFrom(QRToIndex(atk.X,atk.Y), HexState.IsWhiteTurn), atk, kingCords);
	
	}



	// Board Search


	private List<Vector2I> searchForPawnsAtk(Vector2I pos, bool isWTurn)
	{
		int leftCaptureR = isWTurn ? 0 :  1;
		int rightCaptureR = isWTurn ? -1 : 0;
		int qpos = pos.X - 1;
		var lst = new List<Vector2I> {};

		if( Bitboard128.IsLegalHexCords(qpos, leftCaptureR) )
		{
			int index = QRToIndex(qpos, leftCaptureR);
			if( (!BitBoards.IsIndexEmpty(index)) && 
				(BitBoards.IsPieceWhite(index) != isWTurn) )
				if(BitBoards.GetPieceTypeFrom(index, !isWTurn) == PIECES.PAWN)
					lst.Add(new Vector2I(qpos, leftCaptureR));
		}
		qpos = pos.X + 1;
		if( Bitboard128.IsLegalHexCords(qpos, rightCaptureR) )
		{
			int index = QRToIndex(qpos, rightCaptureR);
			if( (!BitBoards.IsIndexEmpty(index)) &&
			 (BitBoards.IsPieceWhite(index) != isWTurn) )
				if(BitBoards.GetPieceTypeFrom(index, !isWTurn) == PIECES.PAWN)
					lst.Add(new Vector2I(qpos, rightCaptureR));
		}
		return lst;
	}
	private List<Vector2I> searchForKnightsAtk(Vector2I pos, bool isWTurn)
	{
		var lst = new List<Vector2I> {};
		int invertAt2Counter = 0;
		foreach(int m in KNIGHT_MULTIPLERS)
			foreach( Vector2I activeVector in KNIGHT_VECTORS.Values)
			{
				int checkingQ = pos.X + (((invertAt2Counter < 2) ? activeVector.X : activeVector.Y) * m);
				int checkingR = pos.Y + (((invertAt2Counter < 2) ? activeVector.Y : activeVector.X) * m);
				if (Bitboard128.IsLegalHexCords(checkingQ,checkingR))
				{
					int index = QRToIndex(checkingQ, checkingR);
					if( ! BitBoards.IsIndexEmpty(index) && (BitBoards.IsPieceWhite(index) != isWTurn) )
						if(BitBoards.GetPieceTypeFrom(index, !isWTurn) == PIECES.KNIGHT)
							lst.Add(new Vector2I(checkingQ, checkingR));
				}
			}
		return lst;
	}
	private List<Vector2I> searchForSlidingAtk(Vector2I pos, bool isWTurn, bool checkForQueens, PIECES initPiece, Dictionary<string,Vector2I> VECTORS)
	{
		var lst = new List<Vector2I> {};
		var checkFor = new List<PIECES> {initPiece};
		if(checkForQueens)
			checkFor.Add(PIECES.QUEEN);
		
		foreach(Vector2I activeVector in VECTORS.Values)
		{
			int checkingQ = pos.X + activeVector.X;
			int checkingR = pos.Y + activeVector.Y;
			while ( Bitboard128.IsLegalHexCords(checkingQ, checkingR) )
			{
				int index = QRToIndex(checkingQ, checkingR);
				if (BitBoards.IsIndexEmpty(index)){}
				else if (BitBoards.IsPieceWhite(index) != isWTurn)
				{
					if ( checkFor.Contains( BitBoards.GetPieceTypeFrom(index, !isWTurn)))
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
	private List<Vector2I> searchForMyAttackers(Vector2I from, bool isWhiteTrn)
	{
		int side = (int)( isWhiteTrn ? SIDES.BLACK : SIDES.WHITE);
		bool hasQueens = BitBoards.ActivePieces[side][PIECES.QUEEN].Count > 0;
		var attackers = new List<Vector2I> {};

		if (BitBoards.ActivePieces[side][PIECES.PAWN].Count > 0)
			attackers.AddRange(searchForPawnsAtk(from, isWhiteTrn));
		if (BitBoards.ActivePieces[side][PIECES.KNIGHT].Count > 0)
			attackers.AddRange(searchForKnightsAtk(from, isWhiteTrn));
		if (BitBoards.ActivePieces[side][PIECES.ROOK].Count > 0 || hasQueens)
			attackers.AddRange(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.ROOK, ROOK_VECTORS));
		if (BitBoards.ActivePieces[side][PIECES.BISHOP].Count > 0 || hasQueens)
			attackers.AddRange(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.BISHOP, BISHOP_VECTORS));
		return attackers;
	}

	
	// Move Do


	private void handleEnpassant(Vector2I cords, Vector2I moveTo)
	{
		var newECords = mGen.filteredMoves[cords][MOVE_TYPES.ENPASSANT][0];
		HexState.EnPassantCords = new Vector2I(newECords.X, newECords.Y + (HexState.IsWhiteTurn ? 1 : -1));
		HexState.EnPassantTarget = moveTo;
		HexState.EnPassantCordsValid = true;
	}
	private bool handleCapture(Vector2I from, Vector2I moveTo, PIECES pieceType)
	{
		bool revertEnPassant = false;
		int moveToIndex = QRToIndex(moveTo.X, moveTo.Y);
		PIECES type = BitBoards.GetPieceTypeFrom(moveToIndex, !HexState.IsWhiteTurn);
		int opColor = (int)(HexState.IsWhiteTurn ? SIDES.BLACK : SIDES.WHITE);

		if(type == PIECES.KING)
		{
			GD.PrintErr(_getBoardFenNow());
			GD.PrintErr("King DIED"); // Should not be possible.
		}

		HexState.CaptureType = type;
		HexState.CaptureValid = true;

		// ENPASSANT FIX
		if(pieceType == PIECES.PAWN && BitBoards.IsIndexEmpty(moveToIndex))
		{
			moveTo.Y += HexState.IsWhiteTurn ?  1 : -1;
			moveToIndex = QRToIndex(moveTo.X, moveTo.Y);
			HexState.CaptureType = BitBoards.GetPieceTypeFrom(moveToIndex, !HexState.IsWhiteTurn);
			revertEnPassant = true;
		}

		mGen.pinningInfluenceCheck(moveTo, from); // capture pinning piece

		BitBoards.ClearIndexOf(QRToIndex(moveTo.X,moveTo.Y),!HexState.IsWhiteTurn,HexState.CaptureType);
		HexState.CaptureIndex = BitBoards.GetAPIndexOf(opColor, HexState.CaptureType, moveTo);
		BitBoards.ActivePieces[opColor][HexState.CaptureType].RemoveAt(HexState.CaptureIndex);
		
		mGen.removeCapturedFromATBoard(HexState.CaptureType, moveTo);

		//Add To Captures
		(HexState.IsWhiteTurn ? HexState.WhiteCaptures : HexState.BlackCaptures).Add(HexState.CaptureType);
		
		return revertEnPassant;
	}
	private void handleMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{
		HexState.ResetTurnFlags();
		//MOVE DATA
		int cordsIndex = QRToIndex(cords.X,cords.Y);
		int selfSide = (int)( HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK );	

		PIECES cordsPIECES = BitBoards.GetPieceTypeFrom(cordsIndex, HexState.IsWhiteTurn);
		int cordsPieceVal = ToPieceInt(cordsPIECES, !HexState.IsWhiteTurn);
		
		Vector2I moveTo = mGen.filteredMoves[cords][moveType][moveIndex];
		HistEntry histEntry = new(cordsPieceVal, cords, moveTo);
		
		//CLEAR LAST POSITION
		BitBoards.ClearIndexOf(cordsIndex, HexState.IsWhiteTurn, cordsPIECES);
		
		//MOVE SPECIFIC ACTIONS (CAPTURE AND/OR SPAWN)
		switch(moveType)
		{
			case MOVE_TYPES.ENPASSANT:
				handleEnpassant(cords, moveTo);
				histEntry.FlipEnPassant();
				break;

			case MOVE_TYPES.CAPTURE:
				if( handleCapture(cords, moveTo, cordsPIECES)) 
					histEntry.FlipTopSneak();
				histEntry.FlipCapture();
				histEntry.CapPiece = HexState.CaptureType;
				histEntry.CapIndex = HexState.CaptureIndex;
				break;

			case MOVE_TYPES.PROMOTE:
				if(moveTo.X != cords.X) //Captured
				{					
					handleCapture(cords, moveTo, cordsPIECES);
					histEntry.FlipCapture();
					histEntry.CapPiece = HexState.CaptureType;
					histEntry.CapIndex = HexState.CaptureIndex;
				}

				int i = BitBoards.GetAPIndexOf(selfSide, cordsPIECES, cords);
				BitBoards.ActivePieces[selfSide][cordsPIECES].RemoveAt(i);
				BitBoards.ActivePieces[selfSide][promoteTo].Add(moveTo);
				cordsPieceVal = ToPieceInt(promoteTo, !HexState.IsWhiteTurn); // ??
				cordsPIECES = promoteTo;
				
				histEntry.FlipPromote();
				histEntry.ProIndex = i;
				histEntry.ProPiece = promoteTo;
				break;

			case MOVE_TYPES.MOVES: break;
			default : throw new Exception("UNKNOWN MOVE_TYPE");
		}

		//UPDATE NEW POSITION
		BitBoards.AddFromIntTo(cordsPIECES, moveTo.X, moveTo.Y, HexState.IsWhiteTurn);
		BitBoards.ClearCombinedStateBitboards();
		BitBoards.GenerateCombinedStateBitboards();
		var index = BitBoards.GetAPIndexOf(selfSide,cordsPIECES,cords);
		BitBoards.ActivePieces[selfSide][cordsPIECES][index] = moveTo;

		//CHECK SELF MOVED PIECE EFFECTS
		GetKings(out Vector2I myking, out Vector2I enemykingCords);
		mGen.generateMovesForPieceMove(cordsPIECES, cords, moveTo, myking);
		if(IsUnderAttack(enemykingCords, mGen.filteredMoves, out List<Vector2I> from)) // moved piece effect caused check?
		{
			histEntry.FlipCheck();
			HexState.IsCheck = true;
			HexState.CheckByMany = from.Count > 1;
			mGen.GameInCheckMoves = new();
			foreach(Vector2I atk in from)
			{
				int atkIndex = QRToIndex(atk.X,atk.Y);
				PIECES type = BitBoards.GetPieceTypeFrom(atkIndex, HexState.IsWhiteTurn);
				mGen.fillInCheckMoves(type, atk, enemykingCords);
			}
		}

		//NEXT TURN
		HexState.NextTurn();
		mGen.addInflunceFrom(moveTo); //GETS STORED IN LAST_INFLUENCED_PIECES ON PURPOSE // TRACKS IF PAWN ENPASSANT CAPTURE IS LEGAL 
		mGen.generateNextLegalMoves(BitBoards.ActivePieces);
		
		if((BitBoards.GetPieceCount() <= 2) || (CountMoves(mGen.filteredMoves) <= 0)) // Kings are the only remaining pieces || Check For CheckMate or StaleMate
		{
			HexState.IsOver = true;
			histEntry.FlipOver();
		}		
		historyStack.Push(histEntry);
		return;
	}


	// Move Undo


	/// <summary>
	/// 
	/// </summary>
	/// <param name="hist"></param>
	private void undoCleanFlags(HistEntry hist)
	{
		if(hist.EnPassant) HexState.EnPassantCordsValid = false;
		if(hist.Over) HexState.IsOver = false;
		if(hist.Check) HexState.IsCheck = false;
		return;
	}
	/// <summary>
	/// 
	/// </summary>
	/// <param name="selfSide"></param>
	/// <param name="activeMove"></param>
	private void undoPromote(int selfSide, HistEntry activeMove)
	{
		// Default added back pawn and cleared nothing. Clear promoted.
		BitBoards.ClearIndexOf(QRToIndex(activeMove.To.X, activeMove.To.Y), HexState.IsWhiteTurn, activeMove.ProPiece);
			
		int size = BitBoards.ActivePieces[selfSide][activeMove.ProPiece].Count;
		BitBoards.ActivePieces[selfSide][activeMove.ProPiece].RemoveAt(size-1);
		BitBoards.ActivePieces[selfSide][PIECES.PAWN].Insert( activeMove.ProIndex, activeMove.From );
		
		HexState.UnpromoteIndex = activeMove.ProIndex;
		HexState.UnpromoteType = activeMove.ProPiece;
		HexState.UnpromoteValid = true;
	}
	/// <summary>
	/// (WIP)
	/// </summary>
	/// <param name="activeMove"></param>
	private void undoCapture(HistEntry activeMove)
	{
		var opside = (int)(HexState.IsWhiteTurn ? SIDES.BLACK : SIDES.WHITE);
		if(activeMove.CaptureTopSneak)
		{
			var temp = activeMove.To;
			temp.Y += HexState.IsWhiteTurn ? 1 :-1;
			activeMove.To = temp;
		}
		BitBoards.AddFromIntTo(activeMove.CapPiece, activeMove.To.X, activeMove.To.Y, !HexState.IsWhiteTurn);
		BitBoards.ActivePieces[opside][activeMove.CapPiece].Insert( activeMove.CapIndex, new Vector2I(activeMove.To.X,activeMove.To.Y) );
		
		mGen.addInflunceFrom(activeMove.To);



		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		
		Vector2I mykingCords = BitBoards.ActivePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
		mGen.prepBlockingFrom(mykingCords);
		//mGen.findLegalMovesFor(mGen.GetAPfromInfluenceOf(activeMove.CapPiece, activeMove.To, activeMove.From));
		mGen.ATKMOD = 1;
		mGen.findPseudoMovesFor(mGen.GetAPfromInfluenceOf(activeMove.From));
		mGen.filterLegalMoves();

		HexState.IsWhiteTurn = !HexState.IsWhiteTurn;



		HexState.UncaptureValid = true;
		HexState.CaptureIndex = activeMove.CapIndex;
		HexState.CaptureType = activeMove.CapPiece;
	
	}
	/// <summary>
	/// 
	/// </summary>
	private void undoOnto()
	{
		if(historyStack.Count <= 0) return; // Cant Onto
		
		var history = historyStack.Pop();
		historyStack.Push(history);

		if(history.Check)
		{
			GetKings(out Vector2I kingCords, out _);
			var attacker = searchForMyAttackers(kingCords, HexState.IsWhiteTurn);

			mGen.GameInCheckMoves = new List<Vector2I> {};
			HexState.IsCheck = true;
			HexState.CheckByMany = attacker.Count > 1; 

			foreach(Vector2I atk in attacker)
			{
				PIECES pieceType = BitBoards.GetPieceTypeFrom(QRToIndex(atk.X, atk.Y), !HexState.IsWhiteTurn);
				mGen.fillInCheckMoves(pieceType, atk, kingCords);
			}
		}	
		if(history.EnPassant)
		{
			var from = history.From;
			var to = history.To;
			var side = (from - to).Y < 0 ? SIDES.BLACK : SIDES.WHITE;
			HexState.EnPassantCordsValid = true;
			HexState.EnPassantTarget = to;
			HexState.EnPassantCords = new Vector2I(to.X, to.Y - (side == SIDES.BLACK ? 1 : -1));
		}
	}
	/// <summary>
	/// 
	/// </summary>
	/// <param name="genMoves"></param>
	private void handleUnMove(bool genMoves)
	{
		HexState.LastTurn();
		HistEntry activeMove = historyStack.Pop();
		
		//UndoVars
		int selfSide = (int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK);
		HexState.UndoType = MaskPieceTypeFrom(activeMove.Piece);
		//AP
		int i = BitBoards.GetAPIndexOf(selfSide, HexState.UndoType, activeMove.To);
		BitBoards.ActivePieces[selfSide][HexState.UndoType][i] = activeMove.From;
		HexState.UndoIndex = i;

		// Default Undo // remove and place in last position
		BitBoards.ClearIndexOf(QRToIndex(activeMove.To.X, activeMove.To.Y), HexState.IsWhiteTurn, HexState.UndoType); 
		BitBoards.AddFromIntTo(HexState.UndoType, activeMove.From.X, activeMove.From.Y, HexState.IsWhiteTurn);
		
		undoCleanFlags(activeMove); //State Specific Undo. CHECK. OVER. ENPASSENT.
		if(activeMove.Promote) // Then Unpromote
			undoPromote(selfSide, activeMove);
		if(activeMove.Capture) // Then Uncapture
			undoCapture(activeMove);

		//Regen
		BitBoards.ClearCombinedStateBitboards();
		BitBoards.GenerateCombinedStateBitboards();

		// Undo Onto
		undoOnto();

		// IF PINNING pieces contains (MoveTo) find path from (MoveFrom) to (Pinned) save in blocking pieces of (Pinned) 
		// Calculate new path and store in blocking
		//limit when ??
		if(!activeMove.Capture && mGen.pinningPieces.ContainsKey(activeMove.To))
		{
			var pinned = mGen.pinningPieces[activeMove.To];
			//Asumes path is possible // fails when bishop or rook path not possible. 
			var path = GetAxialPath(activeMove.From, pinned);
			mGen.pinningPieces.Remove(activeMove.To);
			mGen.pinningPieces[activeMove.From] = pinned;
			mGen.blockingPieces[pinned] = path;
		}

		mGen.addInflunceFrom(activeMove.From); // Enpassant Undo

		if (genMoves)
		  mGen.generateNextLegalMoves(BitBoards.ActivePieces);
	}


	

	// API



	
	/// <summary>
	/// Given a verified FEN String initiate the board states and poopulate the board. 
	/// </summary>
	/// <param name="FEN_STRING"></param>
	/// <returns></returns>
	public bool initiateEngine(string FEN_STRING)
	{
		if ( ! fillBoardwithFEN(FEN_STRING) )
		{
			GD.PushError("Invalid FEN STRING");
			return false;
		}

		BitBoards.ExtractPieceList(); // stored in BitBoards.ActivePieces

		historyStack = new Stack<HistEntry> {};
		moveLock = true;
		
		HexState.resetState();
		mGen.resetState();	

		fillOpAtkBrd();	// ATK BRD set for king moves, check if in CHECK.
		mGen.generateNextLegalMoves(BitBoards.ActivePieces);

		initiateEngineAI();

		return true;		
	}

	/// <summary>
	/// START DEFAULT GAME PUBLIC CALL. 
	/// Calls initiateEngine() with the DEFAULT_FEN_STRING. Starts the default game.
	/// </summary>
	/// <returns>True is success in initiation. False if initiation failed</returns>
	public bool InitiateDefault() { return initiateEngine(DEFAULT_FEN_STRING); }




	public void _restoreState
	(
		Dictionary<int, Dictionary<int,int>> WABoard,
		Dictionary<int, Dictionary<int,int>> BABoard,
		Dictionary<Vector2I, List<Vector2I>> BPieces,
		Dictionary<Vector2I, List<Vector2I>> IPieces,
		Dictionary<Vector2I, Vector2I>       PPieces, 
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> moves
	)
	{
		mGen.WhiteAttackBoard = DeepCopyBoard(WABoard);
		mGen.BlackAttackBoard = DeepCopyBoard(BABoard);
		mGen.blockingPieces = DeepCopyPieces(BPieces);
		mGen.pinningPieces = DeepCopyPinning(PPieces);
		mGen.influencedPieces = DeepCopyPieces(IPieces);
		mGen.filteredMoves = DeepCopyLegalMoves(moves);
		return;
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateWAB() { return DeepCopyBoard(mGen.WhiteAttackBoard); }
	public Dictionary<int, Dictionary<int,int>> _duplicateBAB() { return DeepCopyBoard(mGen.BlackAttackBoard); }	
	public Dictionary<Vector2I, List<Vector2I>> _duplicateBP() { return DeepCopyPieces(mGen.blockingPieces); }
	public Dictionary<Vector2I, List<Vector2I>>  _duplicateIP() { return DeepCopyPieces(mGen.influencedPieces); }
	public Dictionary<Vector2I, Vector2I>  _duplicatePNP() { return DeepCopyPinning(mGen.pinningPieces); }




	/// <summary> RESIGN PUBLIC CALL (WIP) </summary>
	public void _resign()
	{
		if(HexState.IsOver)
		{
			GD.PushWarning("Resigned when no game active.");
			return;
		}
		HexState.IsOver = true;
		return;
	}	




	/// <summary>
	/// PASS TO AI PUBLIC CALL
	/// </summary>
	public void _passToAI()
	{
		if(HexState.IsOver)
			return;
		
		Enemy.EnemyAI._makeChoice(this);
		
		Enemy.EnemyChoiceType = BitBoards.GetPieceTypeFrom(QRToIndex(Enemy.EnemyAI._getCords().X,Enemy.EnemyAI._getCords().Y),  HexState.IsWhiteTurn);
		
		Enemy.EnemyTo = Enemy.EnemyAI._getTo();
		
		Enemy.EnemyChoiceIndex = BitBoards.GetAPIndexOf((int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK), Enemy.EnemyChoiceType, Enemy.EnemyAI._getCords());

		Enemy.EnemyPromoted = Enemy.EnemyAI._getMoveType() == (int) MOVE_TYPES.PROMOTE;
		Enemy.EnemyPromotedTo = (PIECES) Enemy.EnemyAI._getPromoteTo();
		
		handleMove(Enemy.EnemyAI._getCords(),
		 	(MOVE_TYPES) Enemy.EnemyAI._getMoveType(),
			Enemy.EnemyAI._getMoveIndex(), 
			Enemy.EnemyPromotedTo);
		return;
	}
	
	/// <summary>
	/// MAKE MOVE PUBLIC CALL.
	/// TODO:: HANDLE IN PROPER INPUT FEEDBACK.
	/// </summary>
	/// <param name="cords"></param>
	/// <param name="moveType"></param>
	/// <param name="moveIndex"></param>
	/// <param name="promoteTo"></param>
	public void _makeMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{
		if(HexState.IsOver)
		{
			GD.PushWarning("Game Is Over");
			return;
		}
		if(!mGen.filteredMoves.ContainsKey(cords))
		{
			GD.PushWarning("Invalid Move Attempted");
			return;
		}
		if(Enemy.EnemyIsAI && moveLock && (Enemy.EnemyPlaysWhite == HexState.IsWhiteTurn))
		{
			GD.PushError($"It is not your turn. Is AI Turn: {Enemy.EnemyPlaysWhite == HexState.IsWhiteTurn}");
			return;
		}
		handleMove(cords, moveType, moveIndex, promoteTo);
		return;
	}
	

	/// <summary>
	/// Undo Move PUBLIC CALL
	/// </summary>
	/// <param name="genMoves"></param>
	/// <returns></returns>
	public bool _undoLastMove(bool genMoves = true)
	{
		if(historyStack.Count < 1)
			return false;
		handleUnMove(genMoves);
		return true;
	}
	



	/// <summary>
	/// Verify that a fen string is in a LEGAL position.
	/// NEEDS TO BE IMPLEMENTED.
	/// ILLEGAL MOVE IDEAS:
	/// 	1. Pawns can not be on a promoting tile.
	/// 	2. Side to play can not have a move to capture opposing king.
	/// 	3. 
	/// </summary>
	/// <param name="fen"></param>
	/// <returns></returns>
	public bool _FENCHECK(string fen)
	{
		return false;
	}




	/// <summary>
	/// Update Enemy State. Set the enemy type from ENEMY_TYPES. Set the enemy side.
	/// </summary>
	/// <param name="type"> What type of AI or PLAYER_TWO. </param>
	/// <param name="isWhite"> What side will the AI or PLAYER_TWO take.</param>
	public void UpdateEnemy(ENEMY_TYPES type, bool isWhite)
	{
		Enemy.EnemyIsAI = type != ENEMY_TYPES.PLAYER_TWO;
		Enemy.EnemyType = type;
		Enemy.EnemyPlaysWhite = isWhite;
		return;
	}
	public void DisableAIMoveLock()
	{
		moveLock = false;
		return;
	}
	public void EnableAIMoveLock()
	{
		moveLock = true;
		return;
	}
		



	//FEN - BUILDING
	public void FenBuildCleanBB()
	{
		HexState.IsWhiteTurn = true;
		HexState.EnPassantCordsValid = false;
		HexState.TurnNumber = 0;
		BitBoards.InitiateStateBitboards();
	}
	public void FenBuildAddToBB(int type, bool isW, Vector2I pos) { BitBoards.AddFromIntTo((PIECES)type, pos.X, pos.Y, isW); }
	public void FenBuildRemoveFromBB(Vector2I pos, int type, bool isW) { BitBoards.ClearIndexOf(QRToIndex(pos.X,pos.Y), isW, (PIECES) type); }
	public void FenBuildFinishBB() { BitBoards.GenerateCombinedStateBitboards(); }
	public void FenBuilderSetSide(bool wstarts) { HexState.IsWhiteTurn = wstarts; }




	// Getters // bools
	public bool uncaptureValid(){ return HexState.UncaptureValid; }
	public bool unpromoteValid() { return HexState.UnpromoteValid; }
	public bool _getIsWhiteTurn() { return HexState.IsWhiteTurn; }
	public bool _getIsBlackTurn() { return !HexState.IsWhiteTurn; }
	public bool _getEnemyIsWhite() { return Enemy.EnemyPlaysWhite; } 
	public bool _getIsEnemyAI() { return Enemy.EnemyIsAI; }
	public bool _getGameOverStatus() { return HexState.IsOver; }
	public bool CaptureValid() { return HexState.CaptureValid; }
	public bool _getGameInCheck() { return HexState.IsCheck; }
	public bool _getEnemyPromoted() { return Enemy.EnemyPromoted; }
	// ints
	public int _getEnemyPTo() { return (int) Enemy.EnemyPromotedTo; }
	public int CaptureType() { return (int) HexState.CaptureType; }
	public int CaptureIndex() { return HexState.CaptureIndex; }
	public int _getMoveHistorySize() { if (historyStack != null) return historyStack.Count; else return 0; }
	public int undoType() { return (int) HexState.UndoType; }
	public int undoIndex() { return HexState.UndoIndex; }
	public int _getEnemyChoiceType() { return (int) Enemy.EnemyChoiceType; }
	public int _getEnemyChoiceIndex() { return Enemy.EnemyChoiceIndex; }
	public int _getEnemyType() { return (int) Enemy.EnemyType; }
	public int _getEnemyDiff() { return Enemy.EnemyDifficulty; }
	public int getPiecetype(int p) { return (int)MaskPieceTypeFrom(p); }
	public int unpromoteType() { return (int) HexState.UnpromoteType; }
	public int unpromoteIndex() { return (int) HexState.UnpromoteIndex; }
	
	// strings
	public string _getBoardFenNow()
	{
		StringBuilder fen = new StringBuilder();
		var index = 0;
		for(int i=0; i < Bitboard128.COLUMN_SIZES.Length; i +=1 )
		{
			var stack = new Stack<char>();
			var dist = 0;
			for(int j=0; j < Bitboard128.COLUMN_SIZES[i]; j+=1 )
			{
				if(!BitBoards.IsIndexEmpty(index))
				{
					if(dist != 0)
					{
						if(dist > 9)
						{
							stack.Push((char)('0' + (char)(dist-10)));
							stack.Push('1');
						}
						else
							stack.Push((char)('0' + (char)dist));
					}
					var isW = BitBoards.IsPieceWhite(index);
					var p = BitBoards.GetPieceTypeFrom(index,isW);
					stack.Push(PieceToChar(p, isW));
					dist = 0;
				}
				else dist+=1;
				index += 1;
			}
			if(dist != 0)
			{
				if(dist > 9)
				{
					stack.Push((char)('0' + (char)(dist-10)));
					stack.Push('1');
				}
				else
					stack.Push((char)('0' + (char)dist));
			}
			while(stack.Count != 0)
				fen.Append(stack.Pop());
			if(i < Bitboard128.COLUMN_SIZES.Length-1)
				fen.Append('/');
		}
		
		fen.Append(HexState.IsWhiteTurn ? " w " : " b ");
		if(HexState.EnPassantCordsValid) fen.Append(EncodeFEN(HexState.EnPassantCords.X, HexState.EnPassantCords.Y));
		else fen.Append('-');
		
		fen.Append($" {HexState.TurnNumber}");

		return fen.ToString();
	}
	public string _getFullHistString()
	{
		StringBuilder hist = new StringBuilder();
		foreach(HistEntry his in historyStack)
		{
			hist.Append(his.ToString());
			hist.Append("\n");
		}
		return hist.ToString();
	}
	// vectors
	public Vector2I _getEnemyTo() { return Enemy.EnemyTo; }
	// dictionaries
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> GetMoves() { return mGen.filteredMoves; }
	public Dictionary<PIECES, List<Vector2I>>[] GetAPs() { return BitBoards.ActivePieces; }
	



	// STRICT GDSCRIPT INTERACTIONS
	public Godot.Collections.Array<Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>> GDGetActivePieces()
	{
		var gdReturn = new Godot.Collections.Array<Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>>();
		foreach(var side in BitBoards.ActivePieces)
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
	public Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>> GDGetMoves()
	{
		var gdReturn = new Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>>();
		foreach(var key in mGen.filteredMoves.Keys)
		{
			var innerDictionary = new Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>();
			foreach(var innerkey in mGen.filteredMoves[key].Keys)
			{
				var innerList = new Godot.Collections.Array<Vector2I>();
				foreach(var piece in mGen.filteredMoves[key][innerkey])
				{
					innerList.Add(piece);
				}
				innerDictionary.Add(innerkey, innerList);
			}
			gdReturn.Add(key, innerDictionary);
		}
		return gdReturn;
	} 
	public Godot.Collections.Array<string> GetTop5Hist()
	{	
		Godot.Collections.Array<String> Histtop = new Godot.Collections.Array<string>();
		Stack<HistEntry> topStore = new Stack<HistEntry>();
		for (int i = 0; i < 5; i++)
		{
			if(historyStack.Count == 0)
				break;
			var top = historyStack.Pop();
			topStore.Push(top);
			Histtop.Add(top.SimpleString());
		}
		
		while(topStore.Count != 0)
			historyStack.Push(topStore.Pop());
		
		
		return Histtop;
	}
	public Godot.Collections.Dictionary<long, Godot.Collections.Dictionary<long,long>> GetActingAttackBoard()
	{
		
		var finalBoard = new Godot.Collections.Dictionary<long, Godot.Collections.Dictionary<long,long>>();
		var acting = HexState.IsWhiteTurn ? mGen.BlackAttackBoard : mGen.WhiteAttackBoard;
		
		foreach(var key in acting.Keys)
		{
			finalBoard[key] = new();
			foreach(var innerKey in acting[key].Keys)
				finalBoard[key][innerKey] = acting[key][innerKey];
		}
		return finalBoard;
	}



	/// <summary>
	/// Run a test on the engine
	/// </summary>
	/// <param name="type"> Which Test </param>
	public void Test(int type)
	{
		HexTester Tester = new(this);
		switch (type)
		{
			case 0:
				Tester.runFullSuite();
				break;
			case 1:
				GD.Print(Hueristic(this));
			break;
		}
	}
	/// <summary>
	/// Run a test on the engine
	/// </summary>
	/// <param name="type"> Which Test </param>
	public long TestReturnInt(int type)
	{
		HexTester Tester = new(this);
		return type switch
		{
			1 => (Hueristic(this)),
			_ => 0,
		};
	}	




}
