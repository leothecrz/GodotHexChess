using Godot;

using System;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using System.Collections.Generic;

using HexChess;
using static HexChess.HexConst;
using static HexChess.FENConst;

[GlobalClass]
public partial class HexEngineSharp : Node
{
	/// State Holders
	private BoardState HexState;
	private BitboardState BitBoards;
	private EnemyState Enemy;
	private HexMoveGenerator mGen;

	/// Internal
	//private Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves; // MOVES // Might not be necessary
	private Dictionary<PIECES, List<Vector2I>>[] activePieces; // PIECES
	private Stack<HistEntry> historyStack; // HISTORY
	private bool bypassMoveLock; //MOVE AUTH


	/// <summary>
	/// Constructor. Initiates state holders and the move generator.
	/// HexEngineSharp is the master cordinator of the engine module.
	/// </summary>
	public HexEngineSharp()
	{
		HexState = new BoardState();
		BitBoards = new BitboardState();
		Enemy = new EnemyState();
		mGen = new HexMoveGenerator(ref HexState,ref BitBoards);
		activePieces = null;
		historyStack = null;
		bypassMoveLock = true;
	}

	///Utility
	private void GetKings(out Vector2I myking, out Vector2I theirKing)
	{
		 myking = activePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
		 theirKing = activePieces[(int)(HexState.IsWhiteTurn ?  SIDES.BLACK : SIDES.WHITE)][PIECES.KING][KING_INDEX];
	}

	private int GetPieceCount()
	{
		var pieceCount = 0; 
		foreach(var side in activePieces)
			foreach(var  type in side.Keys)
				foreach(var piece in side[type])
					pieceCount+=1;
		return pieceCount;
	}


	/// Board Search

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
		bool hasQueens = activePieces[side][PIECES.QUEEN].Count > 0;
		var attackers = new List<Vector2I> {};

		if (activePieces[side][PIECES.PAWN].Count > 0)
			attackers.AddRange(searchForPawnsAtk(from, isWhiteTrn));
		if (activePieces[side][PIECES.KNIGHT].Count > 0)
			attackers.AddRange(searchForKnightsAtk(from, isWhiteTrn));
		if (activePieces[side][PIECES.ROOK].Count > 0 || hasQueens)
			attackers.AddRange(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.ROOK, ROOK_VECTORS));
		if (activePieces[side][PIECES.BISHOP].Count > 0 || hasQueens)
			attackers.AddRange(searchForSlidingAtk(from, isWhiteTrn, hasQueens, PIECES.BISHOP, BISHOP_VECTORS));
		return attackers;
	}


	// Fill The Board by translating a fen string. DOES NOT FULLY VERIFY FEN STRING -- (W I P)
	private bool fillBoardwithFEN(string fenString)
	{
		//Board Status
		BitBoards.InitiateStateBitboards();
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
			HexState.EnPassantCordsValid = true;
			HexState.EnPassantTarget = DecodeFEN(fenSections[2]);
			HexState.EnPassantCords = new Vector2I(HexState.EnPassantTarget.X, HexState.EnPassantTarget.Y + (HexState.IsWhiteTurn ? -1 : 1));
		}
		else
		{
			HexState.EnPassantCords = new Vector2I(-5,-5);
			HexState.EnPassantTarget = new Vector2I(-5,-5);
			HexState.EnPassantCordsValid = false;
		}
		// Turn Number
		HexState.TurnNumber = fenSections[3].ToInt();
		if(HexState.TurnNumber < 1)
			HexState.TurnNumber = 1;
			
		if(BitBoards.BoardEmpty())
		{
			GD.PushError("Empty Board");
			return false;
		}

		return true;
	}


	// Move Do
	
	private bool handleMoveCapture(Vector2I moveTo, PIECES pieceType)
	{
		bool revertEnPassant = false;
		int moveToIndex = QRToIndex(moveTo.X, moveTo.Y);
		PIECES type = BitBoards.GetPieceTypeFrom(moveToIndex, !HexState.IsWhiteTurn);
		int opColor = (int)(HexState.IsWhiteTurn ? SIDES.BLACK : SIDES.WHITE);
		int i = 0;

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


		BitBoards.ClearIndexOf(QRToIndex(moveTo.X,moveTo.Y),!HexState.IsWhiteTurn,HexState.CaptureType);
		
		
		foreach(Vector2I pieceCords in activePieces[opColor][HexState.CaptureType])
		{
			if(moveTo == pieceCords)
			{
				HexState.CaptureIndex = i;
				break;
			}
			i += 1;
		}

		activePieces[opColor][HexState.CaptureType].RemoveAt(i);
		mGen.removeCapturedFromATBoard(HexState.CaptureType, moveTo);

		// ENPASSANT FIX
		if(revertEnPassant)
			moveTo.Y += HexState.IsWhiteTurn ? -1 : 1;

		//Add To Captures
		if(HexState.IsWhiteTurn) HexState.WhiteCaptures.Add(HexState.CaptureType);
		else HexState.BlackCaptures.Add(HexState.CaptureType);
		return revertEnPassant;
	}
	private void handleMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{
		int index = QRToIndex(cords.X,cords.Y);
		PIECES pieceType = BitBoards.GetPieceTypeFrom(index, HexState.IsWhiteTurn);
		
		int pieceVal = ToPieceInt(pieceType, !HexState.IsWhiteTurn);
		int previousPieceVal = pieceVal;
		int selfColor = (int)( HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK );
		
		Vector2I moveTo = mGen.moves[cords][moveType][moveIndex];
		HistEntry histEntry = new(pieceVal, cords, moveTo);

		BitBoards.ClearIndexFrom(index, HexState.IsWhiteTurn);

		switch(moveType)
		{
			case MOVE_TYPES.PROMOTE:
				if(moveTo.X != cords.X)
				{
					histEntry.FlipCapture();
					histEntry.CapPiece = HexState.CaptureType;
					histEntry.CapIndex = HexState.CaptureIndex;
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
				pieceType = MaskPieceTypeFrom((int)promoteTo);
				pieceVal = ToPieceInt(pieceType, !HexState.IsWhiteTurn);
				activePieces[selfColor][pieceType].Add(moveTo);
				
				histEntry.FlipPromote();
				histEntry.ProPiece = pieceType;
				histEntry.ProIndex = i;
				break;
				

			case MOVE_TYPES.ENPASSANT:
				var newECords = mGen.moves[cords][MOVE_TYPES.ENPASSANT][0];
				HexState.EnPassantCords = new Vector2I(newECords.X, newECords.Y + (HexState.IsWhiteTurn ? 1 : -1));
				HexState.EnPassantTarget = moveTo;
				HexState.EnPassantCordsValid = true;
				histEntry.FlipEnPassant();
				break;
				
			case MOVE_TYPES.CAPTURE:
				histEntry.FlipCapture();
				if( handleMoveCapture(moveTo, pieceType))
					histEntry.FlipTopSneak();
				histEntry.CapIndex = HexState.CaptureIndex;
				histEntry.CapPiece = HexState.CaptureType;
				break;

			case MOVE_TYPES.MOVES: break;
		}

		BitBoards.AddFromIntTo(pieceType, moveTo.X, moveTo.Y, HexState.IsWhiteTurn);
		BitBoards.ClearCombinedStateBitboards();
		BitBoards.GenerateCombinedStateBitboards();

		// Update Piece List
		for(int i = 0; i < activePieces[selfColor][pieceType].Count; i += 1)
			if (activePieces[selfColor][pieceType][i] == cords)
			{
				activePieces[selfColor][pieceType][i] = moveTo;
				break;
			}

		GetKings(out Vector2I mykingCords, out Vector2I enemykingCords );

		mGen.rmvSelfAtks(cords, MaskPieceTypeFrom(previousPieceVal));
		mGen.prepBlockingFrom(mykingCords);
		mGen.findLegalMovesFor(mGen.setupActiveForSingle(pieceType, moveTo, cords));
		mGen.filterLegalMoves();

		if(IsUnderAttack(enemykingCords, mGen.moves, out List<Vector2I> from))
		{
			histEntry.FlipCheck();
			if(from.Count > 1)
			{
				HexState.CheckByMany = true;
				mGen.GameInCheckMoves = new();
				foreach(Vector2I atk in from)
					mGen.fillInCheckMoves(BitBoards.GetPieceTypeFrom(QRToIndex(atk.X,atk.Y), HexState.IsWhiteTurn), atk, enemykingCords, false);
			}
			else
			{
				mGen.fillInCheckMoves(BitBoards.GetPieceTypeFrom(QRToIndex(from[0].X,from[0].Y), HexState.IsWhiteTurn), from[0], enemykingCords, true);
			}
		}

		HexState.NextTurn();
		mGen.addInflunceFrom(moveTo);
		mGen.generateNextLegalMoves(activePieces);

		// Kings are the only remaining pieces || Check For CheckMate or StaleMate
		if((GetPieceCount() <= 2) || (CountMoves(mGen.moves) <= 0)) 
		{
			HexState.IsOver = true;
			histEntry.FlipOver();
		}
		historyStack.Push(histEntry);

		return;
	}


	/// Move Undo
	private void undoSubCleanFlags(Vector2I from, Vector2I to, HistEntry hist)
	{
		var selfSide = (int)( HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK );
		
		if(hist.EnPassant) HexState.EnPassantCordsValid = false;
		if(hist.Over) HexState.IsOver = false;
		if(hist.Check) HexState.IsCheck = false;
		
		if(hist.Promote)
		{
			BitBoards.ClearIndexOf(QRToIndex(to.X, to.Y), HexState.IsWhiteTurn, hist.ProPiece);
			
			int size = activePieces[selfSide][hist.ProPiece].Count;
			activePieces[selfSide][hist.ProPiece].RemoveAt(size-1);
			activePieces[selfSide][PIECES.PAWN].Insert( hist.ProIndex, new Vector2I(from.X,from.Y) );
			
			HexState.UnpromoteValid = true;
			HexState.UnpromoteIndex = hist.ProIndex;
			HexState.UnpromoteType = hist.ProPiece;
		}
		if(hist.Capture)
		{
			if(hist.CaptureTopSneak)
				to.Y += HexState.IsWhiteTurn ? 1 :-1;
			BitBoards.AddFromIntTo(hist.CapPiece, to.X, to.Y, !HexState.IsWhiteTurn);
			activePieces[(int)(HexState.IsWhiteTurn ? SIDES.BLACK : SIDES.WHITE)][hist.CapPiece].Insert( hist.CapIndex, new Vector2I(to.X,to.Y) );
			
			mGen.addInflunceFrom(to);

			HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
			
			Vector2I mykingCords = activePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
			mGen.prepBlockingFrom(mykingCords);
			mGen.findLegalMovesFor(mGen.setupActiveForSingle(hist.CapPiece, to, from));
			mGen.filterLegalMoves();

			HexState.IsWhiteTurn = !HexState.IsWhiteTurn;

			HexState.UncaptureValid = true;
			HexState.CaptureIndex = hist.CapIndex;
			HexState.CaptureType = hist.CapPiece;
	
		}
		return;
	}
	// Moves should be generated by caller function afterwards
	private void undoSubFixState(){
		if(historyStack.Count <= 0)
			return;
		
		var history = historyStack.Pop();
		historyStack.Push(history);

		if(history.Check)
		{
			// TODO :: NEEDS TO SWITCH TO FROMLIST
			var kingCords = activePieces[(int)( HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
			var attacker = searchForMyAttackers(kingCords, HexState.IsWhiteTurn);
			mGen.GameInCheckMoves = new List<Vector2I> {};
			HexState.IsCheck = true;
			foreach(Vector2I atk in attacker)
			{
				PIECES pieceType = BitBoards.GetPieceTypeFrom(QRToIndex(atk.X, atk.Y), !HexState.IsWhiteTurn);
				mGen.fillInCheckMoves(pieceType, atk, kingCords, false);
			}
		}	
		if(history.EnPassant)
		{
			HexState.EnPassantCordsValid = true;
			var from = history.From;
			var to = history.To;
			var side = ((from - to).Y) < 0 ? SIDES.BLACK : SIDES.WHITE;
			HexState.EnPassantTarget = to;
			HexState.EnPassantCords = new Vector2I(to.X, to.Y - (side == SIDES.BLACK ? 1 : -1));
		}
		return;
	}
	
	

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
		mGen.moves = DeepCopyLegalMoves(moves);
		return;
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateWAB() { return DeepCopyBoard(mGen.WhiteAttackBoard); }
	public Dictionary<int, Dictionary<int,int>> _duplicateBAB() { return DeepCopyBoard(mGen.BlackAttackBoard); }	
	public Dictionary<Vector2I, List<Vector2I>> _duplicateBP() { return DeepCopyPieces(mGen.blockingPieces); }
	public Dictionary<Vector2I, List<Vector2I>>  _duplicateIP() { return DeepCopyPieces(mGen.influencedPieces); }
	public Dictionary<Vector2I, Vector2I>  _duplicatePNP() { return DeepCopyPinning(mGen.pinningPieces); }

	///Init
	private void initiateEngineAI()
	{
		if(! Enemy.EnemyIsAI)
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
				Enemy.EnemyAI = new MinMaxAI(Enemy.EnemyPlaysWhite, 2);
				break;
		}
		return;
	}
	/// <summary>
	/// 
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

		historyStack = new Stack<HistEntry> {};

		HexState.BlackCaptures.Clear();
		HexState.WhiteCaptures.Clear();
		
		bypassMoveLock = false;

		HexState.IsOver = false;
		HexState.IsCheck = false;
		HexState.CaptureValid = false;

		HexState.GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);

		activePieces = BitBoards.ExtractPieceList();

		{	
			HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
			GetKings(out Vector2I mykingCords, out Vector2I enemykingCords);
			mGen.prepBlockingFrom(mykingCords);
			mGen.findLegalMovesFor(activePieces[(int)(HexState.IsWhiteTurn ?  SIDES.WHITE : SIDES.BLACK)]);
			mGen.filterLegalMoves();
			if(IsUnderAttack(enemykingCords, mGen.moves, out List<Vector2I> from))
			{
				if(from.Count > 1)
				{
					HexState.CheckByMany = true;
					mGen.GameInCheckMoves = new();
					foreach(Vector2I atk in from)
						mGen.fillInCheckMoves(BitBoards.GetPieceTypeFrom(QRToIndex(atk.X,atk.Y), HexState.IsWhiteTurn), atk, enemykingCords, false);
				}
				else
					mGen.fillInCheckMoves(BitBoards.GetPieceTypeFrom(QRToIndex(from[0].X,from[0].Y), HexState.IsWhiteTurn), from[0], enemykingCords, true);
			}
			HexState.IsWhiteTurn = !HexState.IsWhiteTurn;
		}

		mGen.generateNextLegalMoves(activePieces);

		initiateEngineAI();

		return true;		
	}
	/// <summary>
	/// Calls initiateEngine() with the DEFAULT_FEN_STRING. Starts the default game.
	/// </summary>
	/// <returns>True is success in initiation. False if initiation failed</returns>
	public bool InitiateDefault() { return initiateEngine(DEFAULT_FEN_STRING); }




	/// API
	
	//## MAKE MOVE PUBLIC CALL
	//# TODO:: HANDLE IN PROPER INPUT FEEDBACK
	public void _makeMove(Vector2I cords, MOVE_TYPES moveType, int moveIndex, PIECES promoteTo)
	{

		if(HexState.IsOver)
		{
			GD.PushWarning("Game Is Over");
			return;
		}

		if(!mGen.moves.ContainsKey(cords))
		{
			GD.PushWarning("Invalid Move Attempted");
			return;
		}

		if(Enemy.EnemyIsAI)
			if (bypassMoveLock && (Enemy.EnemyPlaysWhite == HexState.IsWhiteTurn))
			{
				GD.PushError($"It is not your turn. Is AI Turn: {Enemy.EnemyPlaysWhite == HexState.IsWhiteTurn}");
				return;
			}

		HexState.ResetTurnFlags();
		handleMove(cords, moveType, moveIndex, promoteTo);
		return;
	}
	
	public void _passToAI()
	{
		if(HexState.IsOver)
			return;
		
		Enemy.EnemyAI._makeChoice(this);
		
		Enemy.EnemyChoiceType = BitBoards.GetPieceTypeFrom(QRToIndex(Enemy.EnemyAI._getCords().X,Enemy.EnemyAI._getCords().Y),  HexState.IsWhiteTurn);
		
		Enemy.EnemyTo = Enemy.EnemyAI._getTo();
		
		Enemy.EnemyPromoted = Enemy.EnemyAI._getMoveType() == (int) MOVE_TYPES.PROMOTE;
		Enemy.EnemyPromotedTo = (PIECES) Enemy.EnemyAI._getPromoteTo();

		Enemy.EnemyChoiceIndex = 0;
		foreach( Vector2I pieceCords in activePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][Enemy.EnemyChoiceType])
		{
			if(pieceCords == Enemy.EnemyAI._getCords()) break;
			Enemy.EnemyChoiceIndex += 1;
		}
		
		HexState.ResetTurnFlags();
		
		handleMove(Enemy.EnemyAI._getCords(), (MOVE_TYPES) Enemy.EnemyAI._getMoveType(), Enemy.EnemyAI._getMoveIndex(), Enemy.EnemyPromotedTo);
		return;
	}
	// RESIGN PUBLIC 
	
	public void _resign()
	{
		BitBoards.ClearCombinedStateBitboards();
		BitBoards.ClearStateBitboards();
		if(HexState.IsOver)
			return;
		HexState.IsOver = true;
		return;
	}
	// Undo Move PUBLIC CALL
	
	public bool _undoLastMove(bool genMoves = true)
	{
		if(historyStack.Count < 1)
			return false;

		HistEntry activeMove = historyStack.Pop();
		HexState.LastTurn();

		//UndoVars & APs
		HexState.UndoType = MaskPieceTypeFrom(activeMove.Piece);
		var pieceList = activePieces[(int)(HexState.IsWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][HexState.UndoType];
		for(int i=0; i < pieceList.Count; i+=1 )
		{
			if(pieceList[i] != activeMove.To)
				continue;
			pieceList[i] = activeMove.From;
			HexState.UndoIndex = i;
			break;
		}

		// Default Undo
		BitBoards.ClearIndexOf(QRToIndex(activeMove.To.X, activeMove.To.Y), HexState.IsWhiteTurn, HexState.UndoType); 
		BitBoards.AddFromIntTo(HexState.UndoType, activeMove.From.X, activeMove.From.Y, HexState.IsWhiteTurn);
		undoSubCleanFlags(activeMove.From, activeMove.To, activeMove);

		BitBoards.ClearCombinedStateBitboards();
		BitBoards.GenerateCombinedStateBitboards();

		// Undo Onto
		undoSubFixState();
		
		mGen.addInflunceFrom(activeMove.From);

		if (genMoves)
		  mGen.generateNextLegalMoves(activePieces);

		return true;
	}
	//START DEFAULT GAME PUBLIC CALL

	public bool _FENCHECK(string fen)
	{
		return false;
	}

	public void UpdateEnemy(ENEMY_TYPES type, bool isWhite)
	{
		Enemy.EnemyIsAI = type != ENEMY_TYPES.PLAYER_TWO;
		Enemy.EnemyType = type;
		Enemy.EnemyPlaysWhite = isWhite;
		return;
	}
	public void DisableAIMoveLock()
	{
		bypassMoveLock = false;
		return;
	}
	public void EnableAIMoveLock()
	{
		bypassMoveLock = true;
		return;
	}
		



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




	/// Getter // bools
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
							stack.Push('1');
							stack.Push((char)('0' + (char)(dist-10)));
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
					stack.Push('1');
					stack.Push((char)('0' + (char)(dist-10)));
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
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> GetMoves() { return mGen.moves; }
	public Dictionary<PIECES, List<Vector2I>>[] GetAPs() { return activePieces; }
	



	/// STRICT GDSCRIPT INTERACTIONS
	public Godot.Collections.Array<Godot.Collections.Dictionary<PIECES, Godot.Collections.Array<Vector2I>>> GDGetActivePieces()
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
	public Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>> GDGetMoves()
	{
		var gdReturn = new Godot.Collections.Dictionary<Vector2I,Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>>();
		foreach(var key in mGen.moves.Keys)
		{
			var innerDictionary = new Godot.Collections.Dictionary<MOVE_TYPES, Godot.Collections.Array<Vector2I>>();
			foreach(var innerkey in mGen.moves[key].Keys)
			{
				var innerList = new Godot.Collections.Array<Vector2I>();
				foreach(var piece in mGen.moves[key][innerkey])
				{
					innerList.Add(piece);
				}
				innerDictionary.Add(innerkey, innerList);
			}
			gdReturn.Add(key, innerDictionary);
		}
		return gdReturn;
	} 
	public Godot.Collections.Array<String> GetTop5Hist()
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
