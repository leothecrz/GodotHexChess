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

	private int maxDepth;

	private Dictionary<Vector2I, List<long>> hashBoardValues;
	private Dictionary<long, TableEntry> transpositionTable;

	long whiteTurnHashValue;
	long blackTurnHashValue;
	long counter = 0;
	long QCounter = 0;
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
		foreach(var side in reference.GetAPs())
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


	private long QuiescenceSearch(HexEngineSharp hexEngine, int multiplier, long alpha, long beta)
	{
		QCounter += 1;

		long positionHash = getPositionHash(hexEngine, multiplier < 0);
		bool hasEntry = transpositionTable.TryGetValue(positionHash, out TableEntry entry);
		if(hasEntry && entry.depth >= 0)
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
		
		long standingValue = multiplier * Hueristic(hexEngine);
		if(standingValue >= beta) return beta;
		if(alpha < standingValue) alpha = standingValue;

		int index;
		long value = long.MinValue;

		var snap = hexEngine._snapshotState();

		var legalmoves = snap.filteredMoves;

		//List<long> postQ = new();

		foreach( Vector2I piece in legalmoves.Keys )
		{
			index = 0;
			foreach( Vector2I move in legalmoves[piece][MOVE_TYPES.CAPTURE] )
			{
				hexEngine._makeMove(piece, MOVE_TYPES.CAPTURE, index, PIECES.QUEEN);
				var newVal = -QuiescenceSearch(hexEngine, -multiplier, -beta, -alpha);
				//postQ.Add(newVal);
				value = Math.Max(newVal, value);
				alpha = Math.Max(alpha, value);
				
				hexEngine._undoLastMove(false);
				hexEngine._restoreSnapshot(snap);
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
		transpositionTable[positionHash] = new TableEntry(value, 0, type);

		return alpha;
	}

	// Recursive Move Check
	private long NegativeMaximum(HexEngineSharp hexEngine, int depth, int multiplier, long alpha, long beta)
	{
		counter += 1;
		
		long positionHash = getPositionHash(hexEngine, multiplier < 0);
		bool hasEntry = transpositionTable.TryGetValue(positionHash, out TableEntry entry);
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
			return QuiescenceSearch(hexEngine, -multiplier, -beta, -alpha);
			//return multiplier * Hueristic(hexEngine);
		}
			
		int index = 0;
		long value = long.MinValue;

		var snap = hexEngine._snapshotState();

		var legalmoves = snap.filteredMoves;
		
		//Insert Move Ordering Here

		foreach( Vector2I piece in legalmoves.Keys )
			foreach( MOVE_TYPES movetype in legalmoves[piece].Keys )
			{
				index = 0;
				foreach( Vector2I move in legalmoves[piece][movetype] )
				{
					
					hexEngine._makeMove(piece,movetype,index,PIECES.QUEEN);
					
					value = Math.Max(-NegativeMaximum(hexEngine, depth-1, -multiplier, -beta, -alpha), value);
					alpha = Math.Max(alpha, value);
					
					hexEngine._undoLastMove(false);
					hexEngine._restoreSnapshot(snap);
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
		var snap = hexEngine._snapshotState();
		var legalmoves = snap.filteredMoves;

		hexEngine.DisableAIMoveLock();
		CORDS = new Vector2I(-6,-6);
		counter = 0;
		QCounter = 0;
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
						hexEngine._makeMove(piece,movetype,index,PIECES.QUEEN);
						long val = NegativeMaximum(hexEngine, depth, isMaxPlayer ? 1 : -1, long.MinValue, long.MaxValue);
						
						if (BestValue < val)
						{
							BestValue = val;
							selectMove(piece, (int)movetype, index, move);
							GD.Print($"Cords: ({CORDS.X},{CORDS.Y}), To: ({TO.X},{TO.Y}), Type: {MOVETYPE}, Index: {MOVEINDEX} \n");
						}
						index += 1;
						hexEngine._undoLastMove(false);
						hexEngine._restoreSnapshot(snap);
					}
				}
			
		

		GD.Print($"Move Gen For Depth {maxDepth}+1 took {Time.GetTicksUsec() - start} microseconds");
		GD.Print("MinMax Calls: ", counter);
		GD.Print("Quiescence  Calls: ", QCounter);
		GD.Print("Evals Made: ", statesEvaluated);
		GD.Print("Positions Found: ", positionsFound);
		GD.Print("Best Value: ", BestValue);
		
		hexEngine.EnableAIMoveLock();

		return;
	}


}


