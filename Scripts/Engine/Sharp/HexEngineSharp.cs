using Godot;

using System;
using System.Collections.Generic;
using System.Linq;
using System.Text.RegularExpressions;

using HexChess;
using static HexChess.HexConst;
using static HexChess.FENConst;

[GlobalClass]
public partial class HexEngineSharp : Node
{
	// States
	private BoardState HexState;		
	private BitboardState BitBoards;
	private EnemyState Enemy;
	// Gen
	private HexMoveGenerator mGen;
	// Pieces
	private Dictionary<PIECES, List<Vector2I>>[] activePieces = null;
	// Moves
	private Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves = null;

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


	/// <summary>
	/// Constructor
	/// </summary>
	public HexEngineSharp()
	{
		HexState = new BoardState();
		BitBoards = new BitboardState();
		Enemy = new EnemyState();
		mGen = new HexMoveGenerator(HexState, BitBoards);
	}


	// Board Search
	private List<Vector2I> searchForPawnsAtk(Vector2I pos, bool isWTurn)
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
	private List<Vector2I> searchForKnightsAtk(Vector2I pos, bool isWTurn)
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

	//
	private void handleMoveState(Vector2I cords, Vector2I lastCords, HistEntry hist)
	{
		UNDO_FLAGS mateStatus = UNDO_FLAGS.NONE;
		PIECES pieceType = BitBoards.PieceTypeOf(QRToIndex(cords.X,cords.Y), !HexState.isWhiteTurn);
		
		Vector2I enemykingCords = activePieces[(int)(HexState.isWhiteTurn ?  SIDES.BLACK : SIDES.WHITE)][PIECES.KING][KING_INDEX];
		Vector2I mykingCords = activePieces[(int)(HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];

		BitBoards.clearCombinedStateBitboards();
		BitBoards.generateCombinedStateBitboards();

		mGen.prepBlockingFrom(mykingCords);
		mGen.findLegalMovesFor(mGen.setupActiveForSingle(pieceType, cords, lastCords));
		if(checkIFCordsUnderAttack(enemykingCords, mGen.moves))
		{
			mateStatus = UNDO_FLAGS.CHECK;
			mGen.fillInCheckMoves(pieceType, cords, enemykingCords, true);
		}
		mGen.addInflunceFrom(cords);

		HexState.nextTurn();

		legalMoves = mGen.generateNextLegalMoves(activePieces);

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
		bool revertEnPassant = false;
		int moveToIndex = QRToIndex(moveTo.X, moveTo.Y);
		PIECES type = BitBoards.PieceTypeOf(moveToIndex, HexState.isWhiteTurn);
		int opColor = (int)(HexState.isWhiteTurn ? SIDES.BLACK : SIDES.WHITE);
		int i = 0;

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
		mGen.removeCapturedFromATBoard(HexState.captureType, moveTo);

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

		mGen.rmvSelfAtks(cords, getPieceType(previousPieceVal));
		
		handleMoveState(moveTo, cords, histEntry);

		return;
	}


	// Move Undo
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
			
			mGen.addInflunceFrom(to);
		}
		return;
	}
	// Moves should be generated by caller function afterwards
	private void undoSubFixState(){
		if(historyStack.Count <= 0)
			return;
		
		var history = historyStack.Pop();
		historyStack.Push(history);

		if(history._getCheck())
		{
			var kingCords = activePieces[(int)( HexState.isWhiteTurn ? SIDES.WHITE : SIDES.BLACK)][PIECES.KING][KING_INDEX];
			var attacker = searchForMyAttackers(kingCords, HexState.isWhiteTurn);
			mGen.GameInCheckMoves = new List<Vector2I> {};
			HexState.isCheck = true;
			foreach(Vector2I atk in attacker)
			{
				PIECES pieceType = BitBoards.PieceTypeOf(QRToIndex(atk.X, atk.Y), HexState.isWhiteTurn);
				mGen.fillInCheckMoves(pieceType, atk, kingCords, false);
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
		mGen.WhiteAttackBoard = DeepCopyBoard(WABoard);
		mGen.BlackAttackBoard = DeepCopyBoard(BABoard);
		mGen.blockingPieces = DeepCopyPieces(BPieces);
		mGen.influencedPieces = DeepCopyPieces(IPieces);
		legalMoves = DeepCopyLegalMoves(moves);
		mGen.moves = legalMoves;
		return;
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateWAB()
	{
		return DeepCopyBoard(mGen.WhiteAttackBoard);
	}
	public Dictionary<int, Dictionary<int,int>> _duplicateBAB()
	{
		return DeepCopyBoard(mGen.BlackAttackBoard);
	}	
	public Dictionary<Vector2I, List<Vector2I>> _duplicateBP()
	{
		return DeepCopyPieces(mGen.blockingPieces);
	}
	public Dictionary<Vector2I, List<Vector2I>>  _duplicateIP()
	{
		return DeepCopyPieces(mGen.influencedPieces);
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

		historyStack = new Stack<HistEntry> {};

		HexState.blackCaptures.Clear();
		HexState.whiteCaptures.Clear();
		
		bypassMoveLock = false;

		HexState.isOver = false;
		HexState.isCheck = false;
		HexState.captureValid = false;

		HexState.GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);

		activePieces = BitBoards.bbfindPieces();

		legalMoves = mGen.generateNextLegalMoves(activePieces);

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

		HexState.resetTurnFlags();
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
		
		HexState.resetTurnFlags();
		
		handleMove(Enemy.EnemyAI._getCords(), (MOVE_TYPES) Enemy.EnemyAI._getMoveType(), Enemy.EnemyAI._getMoveIndex(), Enemy.EnemyPromotedTo);
		return;
	}
	// RESIGN PUBLIC 
	public void _resign()
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
		
		mGen.addInflunceFrom(UndoNewFrom);
		
		BitBoards.clearCombinedStateBitboards();
		BitBoards.generateCombinedStateBitboards();
		
		if(genMoves) 
			legalMoves = mGen.generateNextLegalMoves(activePieces);
		return true;
	}
	//START DEFAULT GAME PUBLIC CALL
	public bool _initDefault()
	{
		//var testing = new List<int> {46, 47, 48, 49, 50, 35, 26, 18, 11, 5, 56, 66, 75, 83, 90, 44, 43, 42, 41, 40, 34, 24, 15, 7, 0, 55, 64, 72, 79, 85 };
		// Bitboard128 test = new Bitboard128(0,0);
		//foreach(int i in testing)
		//{
		// test = test.OR(Bitboard128.createSinglePieceBB(90));
		//}
		// GD.Print(test);

		return initiateEngine(DEFAULT_FEN_STRING);
	}


	// Getters


	//BOOL
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
	//INT
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
	public int _getEnemyType()
	{
		return (int) Enemy.EnemyType;
	}
	//
	public Vector2I _getEnemyTo()
	{
		return Enemy.EnemyTo;
	}
	//
	public Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> _getmoves()
	{
		return legalMoves;
	}
	//
	public Dictionary<PIECES, List<Vector2I>>[] _getAP()
	{
		return activePieces;
	}

	
	//STRICT GDSCRIPT INTERACTIONS
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
	public void _test(int type)
	{
		
		HexTester Tester = new HexTester(this);
		switch (type)
		{
			case 0:
				Tester.runFullSuite();
			break;
		}

		
	}
	


}
