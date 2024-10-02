using Godot;
using System;

using HexChess;
using static HexChess.HexConst;
using System.ComponentModel.DataAnnotations.Schema;
using System.Collections.Generic;

public partial class MinMaxAI : AIBase
{

	private const long PIECE_TYPE_COUNT = 6;

	private int maxDepth;

	Dictionary<Vector2I, List<long>> hashBoardValues;
	//Dictionary<int, Dictionary<int, int>> transpositionTable;

	long whiteTurnHashValue;
	long blackTurnHashValue;
	long counter = 0;
	long statesEvaluated = 0;
	long positionsFound = 0;	
	
	// Create A hexagonal board with axial cordinates. (Q,R). Centers At 0,0.
	private Dictionary<Vector2I, List<long>> createTranspositionBoard(int radius)
	{
		var Board = new Dictionary<Vector2I, List<long>>();
		var rng = new Random( (int) Time.GetUnixTimeFromSystem());

		whiteTurnHashValue = rng.NextInt64();
		blackTurnHashValue = rng.NextInt64();
		
		for(int q = -radius; q <= radius; q+=1)
		{
			var negativeQ = -1 * q;
			var minRow = Math.Max(-radius, (negativeQ-radius));
			var maxRow = Math.Min( radius, (negativeQ+radius));
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

	public MinMaxAI(bool playswhite, int maxdepth)
	{
		this.side = (int)( playswhite ? SIDES.WHITE : SIDES.BLACK );
		maxDepth = maxdepth;
		// For Promote moves should check if knight or queen is best choice (WIP)
		PROMOTETO = 5;
		
		//hashBoardValues = createTranspositionBoard(HexEngine.HEX_BOARD_RADIUS);
		//transpositionTable = {};
		
		return;
	}


	private void Tabl()
	{
		
	}




	public override void _makeChoice(HexEngineSharp HexEngine)
	{
		return;
	}


}


