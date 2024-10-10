using Godot;
using System;

using HexChess;
using static HexChess.HexConst;

using System.ComponentModel.DataAnnotations.Schema;
using System.Collections.Generic;
using System.Reflection.Metadata.Ecma335;
using GodotPlugins.Game;

public partial class MinMaxAI : AIBase
{

	private const long PIECE_TYPE_COUNT = 6;
	private const long DIST_VALUE = 10000;
	private const long KING_DIST_VALUE = DIST_VALUE / 5;
	private const long CHECK_VAL = 15000;
	//skip ZERO and ignore king *(its always present) 
	private static readonly long[] PIECE_VALUES = new long[] {0, 1000, 3000, 5000, 3000, 9000, 0};

	private static readonly long [][] PIECE_BOARDS = 
		{
			new long[] {  }, //ZERO
			new long[] { // PAWNS 
					 120,50,25,25,50,120,
				    110,50,25,0,25,50,110,
				   100,50,25,0,0,25,50,100,
				  100,50,25,0,0,0,25,50,100,
				 100,50,25,0,0,0,0,25,50,100,
				100,50,25,0,0,0,0,0,25,50,100,
				 100,50,25,0,0,0,0,25,50,100,
				  100,50,25,0,0,0,25,50,100,
				   100,50,25,0,0,25,50,100,
				    110,50,25,0,25,50,110,
				     120,50,25,25,50,120, },
			new long[] { //KNIGHT
					     10,10,10,10,10,10,
				       10,20,20,20,20,20,10,
				      10,20,50,50,50,50,20,10,
				    10,20,50,100,100,100,50,20,10,
				  10,20,50,100,100,100,100,50,20,10,
				10,20,50,100,100,100,100,100,50,20,10,
				  10,20,50,100,100,100,100,50,20,10,
				    10,20,50,100,100,100,50,20,10,
				      10,20,50,50,50,50,20,10,
				       10,20,20,20,20,20,10,
				         10,10,10,10,10,10, },
			new long[] { //ROOK
					 0,100,0,0,100,0,
				    0,100,0,0,0,100,0,
				   0,100,0,0,0,0,100,0,
				  0,100,0,100,100,100,0,100,0,
				 0,100,0,100,0,0,100,0,100,0,
				0,100,0,100,0,100,0,100,0,100,0,
				 0,100,0,100,0,0,100,0,100,0,
				  0,100,0,100,100,100,0,100,0,
				   0,100,0,0,0,0,100,0,
				    0,100,0,0,0,100,0,
				     0,100,0,0,100,0, },
			new long[] { //BISHOP
					 0,0,0,0,0,0,
				    50,0,0,0,0,0,50,
				   40,60,0,0,0,0,60,40,
				  30,0,0,70,0,0,70,0,30,
				 20,30,0,80,80,80,80,0,30,20,
				0,0,0,125,125,100,125,125,0,0,0,
				 20,30,0,80,80,80,80,0,30,20,
				  30,0,0,70,0,0,70,0,30,
				   40,60,0,0,0,0,60,40,
				    50,0,0,0,0,0,50,
				     0,0,0,0,0,0, },
			new long[] { //QUEEN
					 0,0,0,0,0,0,
				    0,0,0,0,0,0,0,
				   0,0,0,0,0,0,0,0,
				  0,0,0,0,0,0,0,0,0,
				 0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,
				 0,0,0,0,0,0,0,0,0,0,
				  0,0,0,0,0,0,0,0,0,
				   0,0,0,0,0,0,0,0,
				    0,0,0,0,0,0,0,
				     0,0,0,0,0,0, },
			new long[] { //KING
					 0,0,0,0,0,0,
				    0,0,0,0,0,0,0,
				   0,0,0,0,0,0,0,0,
				  0,0,0,0,0,0,0,0,0,
				 0,0,0,0,0,0,0,0,0,0,
				0,0,0,0,0,0,0,0,0,0,0,
				 0,0,0,0,0,0,0,0,0,0,
				  0,0,0,0,0,0,0,0,0,
				   0,0,0,0,0,0,0,0,
				    0,0,0,0,0,0,0,
				     0,0,0,0,0,0, }
		};


	private int maxDepth;

	private Dictionary<Vector2I, List<long>> hashBoardValues;
	private Dictionary<long, TableEntry> transpositionTable;

	long whiteTurnHashValue;
	long blackTurnHashValue;
	long counter = 0;
	long statesEvaluated = 0;
	long positionsFound = 0;	

	//	
	public MinMaxAI(bool playswhite, int maxdepth)
	{
		this.side = (int)( playswhite ? SIDES.WHITE : SIDES.BLACK );
		maxDepth = maxdepth;
		// For Promote moves should check if knight or queen is best choice (WIP)
		PROMOTETO = 5;
		
		var rng = new Random( (int) Time.GetUnixTimeFromSystem());
		whiteTurnHashValue = rng.NextInt64();
		blackTurnHashValue = rng.NextInt64();

		hashBoardValues = createTranspositionBoard(HEX_BOARD_RADIUS);
		transpositionTable = new Dictionary<long, TableEntry>();
		
		return;
	}

	// Create A hexagonal board with axial cordinates. (Q,R). Centers At 0,0.
	private static Dictionary<Vector2I, List<long>> createTranspositionBoard(int radius)
	{
		var Board = new Dictionary<Vector2I, List<long>>();
		var rng = new Random( (int) Time.GetUnixTimeFromSystem());
		
		for(int q = -radius; q <= radius; q+=1)
		{
			var negativeQ = -1 * q;
			var minRow = Math.Max(-radius, negativeQ-radius);
			var maxRow = Math.Min( radius, negativeQ+radius);
			for(int r=minRow; r<=maxRow; r+=1)
			{
				var posValues = new List<long>();
				for(int n=0; n < PIECE_TYPE_COUNT; n+=1)
					posValues.Add(rng.NextInt64());
				Board[new Vector2I(q,r)] = posValues;
			}
		}
		return Board;	
	}
	private long getPositionHash(HexEngineSharp reference, bool isWTurn )
	{
		long hash = isWTurn ? whiteTurnHashValue : blackTurnHashValue;
		foreach(var side in reference._getAP())
		{
			foreach(PIECES type in side.Keys)
			{
				foreach(Vector2I piece in side[type])
				{
					hash ^= hashBoardValues[piece][(int)type-1];
				}
			}
		}
		return hash;
	}
	
	private void selectMove(Vector2I piece, int movetype, int index, Vector2I move)
	{
		CORDS = piece;
		TO = move;
		
		MOVEINDEX = index;
		MOVETYPE = movetype;
	}


	// Measure Board State
	public static long Hueristic(HexEngineSharp hexEngine)
	{
		//ENDSTATE
		if(hexEngine._getGameOverStatus())
		{
			if(hexEngine._getGameInCheck())
			{
				if(hexEngine._getIsWhiteTurn()) return long.MaxValue;
				else return long.MinValue;
			}
			else return 0; // StaleMate
		}
		long H = 0;
		//Check
		if(hexEngine._getGameInCheck())
			if(hexEngine._getIsWhiteTurn())
				H += CHECK_VAL;
			else
				H -= CHECK_VAL;
		//Piece Comparison
		foreach(PIECES piecetype in hexEngine._getActivePieces()[(int)SIDES.BLACK].Keys)
			foreach(Vector2I piece in hexEngine._getActivePieces()[(int)SIDES.BLACK][piecetype])
				H += PIECE_VALUES[(int)piecetype];
		foreach(PIECES piecetype in hexEngine._getActivePieces()[(int)SIDES.WHITE].Keys)
			foreach(Vector2I piece in hexEngine._getActivePieces()[(int)SIDES.WHITE][piecetype])
				H -= PIECE_VALUES[(int)piecetype];
		//Push King
		Vector2I WhiteKing = hexEngine._getActivePieces()[(int)SIDES.WHITE][PIECES.KING][0];
		Vector2I BlackKing = hexEngine._getActivePieces()[(int)SIDES.BLACK][PIECES.KING][0];
		var dist = getAxialCordDist(WhiteKing,new Vector2I(0,0));
		H += dist * KING_DIST_VALUE;
		dist = getAxialCordDist(BlackKing,new Vector2I(0,0));
		H -= dist * KING_DIST_VALUE;
		//Push Pawns
		foreach( Vector2I pawn in hexEngine._getActivePieces()[(int)SIDES.WHITE][PIECES.PAWN])
		{
			if(pawn.X >= 0)
				H -= DIST_VALUE * getAxialCordDist(pawn, new Vector2I(pawn.X, -1*HEX_BOARD_RADIUS));
			else
				H -= DIST_VALUE * getAxialCordDist(pawn, new Vector2I(pawn.X, (-1*HEX_BOARD_RADIUS)-pawn.X));
		}
		foreach( Vector2I pawn in hexEngine._getActivePieces()[(int)SIDES.BLACK][PIECES.PAWN])
		{
			if(pawn.X <= 0)
				// axial dist is negative
				H += DIST_VALUE * getAxialCordDist(pawn, new Vector2I(pawn.X, HEX_BOARD_RADIUS));
			else
				H += DIST_VALUE * getAxialCordDist(pawn, new Vector2I(pawn.X, HEX_BOARD_RADIUS-pawn.X));
		}
		return H;
	}

	// Recursive Move Check
	private long NegativeMaximum(HexEngineSharp hexEngine, int depth, int multiplier, long alpha, long beta)
	{
		counter += 1;
		
		long positionHash = getPositionHash(hexEngine, multiplier < 0);
		TableEntry entry;
		bool hasEntry = transpositionTable.TryGetValue(positionHash, out entry);
		if(hasEntry && entry.depth >= depth)
		{
			positionsFound += 1;
			switch(entry.type)
			{
				case TableEntry.ENTRY_TYPE.EXACT: return entry.value;
				case TableEntry.ENTRY_TYPE.LOWER: alpha = Math.Max(alpha, entry.value); break;
				case TableEntry.ENTRY_TYPE.UPPER: beta = Math.Min(beta, entry.value); break;
			}
			if(alpha >= beta) return entry.value;
		}
		
		if( depth == 0 || hexEngine._getGameOverStatus())
		{
			statesEvaluated += 1;
			return multiplier * Hueristic(hexEngine);
		}
			
		int index = 0;
		long value = long.MinValue;
		var legalmoves = DeepCopyLegalMoves(hexEngine._getmoves());
		
		//Insert Move Ordering Here
		foreach( Vector2I piece in legalmoves.Keys )
			foreach( MOVE_TYPES movetype in legalmoves[piece].Keys )
			{
				index = 0;
				foreach( Vector2I move in legalmoves[piece][movetype] )
				{
					var WAB = hexEngine._duplicateWAB();
					var BAB = hexEngine._duplicateBAB();
					var BP = hexEngine._duplicateBP();
					var InPi = hexEngine._duplicateIP();
					
					hexEngine._makeMove(piece,movetype,index,PIECES.QUEEN);
					
					value = Math.Max(-NegativeMaximum(hexEngine, depth-1, -multiplier, -beta, -alpha), value);
					alpha = Math.Max(alpha, value);
					
					hexEngine._undoLastMove(false);
					hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
					index += 1;
					
					if(alpha >= beta) goto ESCAPELOOP;
				}
			}
		ESCAPELOOP:
		
		TableEntry.ENTRY_TYPE type;
		if(value <= alpha)
			type = TableEntry.ENTRY_TYPE.UPPER;
		else if(value >= beta)
			type = TableEntry.ENTRY_TYPE.LOWER;
		else
			type = TableEntry.ENTRY_TYPE.EXACT;
		transpositionTable[positionHash] = new TableEntry(value, depth, type);
		
		return value;
	}




	public override void _makeChoice(HexEngineSharp hexEngine)
	{
		if(hexEngine._getGameOverStatus())
			return;
	
		var start = Time.GetTicksUsec();
		var isMaxPlayer = side == (int) SIDES.BLACK;
		long BestValue = long.MinValue;
		var legalmoves = DeepCopyLegalMoves( hexEngine._getmoves() );

		hexEngine._disableAIMoveLock();
		CORDS = new Vector2I(-6,-6);
		counter = 0;
		positionsFound = 0;
		statesEvaluated = 0;
		
		//Insert Iterative Deepening Here
		for(int depth=1; depth<maxDepth+1; depth +=1)
			foreach( Vector2I piece in legalmoves.Keys )
				foreach( MOVE_TYPES movetype in legalmoves[piece].Keys )
				{
					int index = 0;
					foreach(Vector2I move in legalmoves[piece][movetype])
					{

						var WAB = hexEngine._duplicateWAB();
						var BAB = hexEngine._duplicateBAB();
						var BP = hexEngine._duplicateBP();
						var InPi = hexEngine._duplicateIP();
						
						hexEngine._makeMove(piece,movetype,index,PIECES.QUEEN);
						long val = NegativeMaximum(hexEngine, depth, isMaxPlayer ? 1 : -1, long.MinValue, long.MaxValue);
						
						if (BestValue < val)
						{
							BestValue = val;
							selectMove(piece, (int)movetype, index, move);
							GD.Print($"Cords: ({CORDS.X},{CORDS.Y}), To: ({TO.X},{TO.Y}), Type: {MOVETYPE}, Index: {MOVEINDEX} \n");
						}
						hexEngine._undoLastMove(false);
						hexEngine._restoreState(WAB,BAB,BP,InPi,legalmoves);
					}
				}
			
		

		GD.Print($"Move Gen For Depth {maxDepth}+1 took {Time.GetTicksUsec() - start} microseconds");
		GD.Print("MinMax Calls: ", counter);
		GD.Print("Evals Made: ", statesEvaluated);
		GD.Print("Positions Found: ", positionsFound);
		GD.Print("Best Value: ", BestValue);
		
		hexEngine._enableAIMoveLock();

		return;
	}


}


