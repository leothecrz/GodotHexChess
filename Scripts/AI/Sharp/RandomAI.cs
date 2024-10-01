using System;
using System.Collections.Generic;

using Godot;

using HexChess;
using static HexChess.HexConst;

public partial class RandomAI : AIBase
{

	private Random rng;

	 public RandomAI(bool playswhite)
    {
        PROMOTETO = (int) PIECES.QUEEN;
        side = playswhite ? 1 : 0;
		rng = new Random( (int) Time.GetUnixTimeFromSystem() ); //Precision loss good	
	    return;
    }

	public override void _makeChoice(HexEngineSharp HexEngine)
	{
		List<MOVE_TYPES> allowed = new List<MOVE_TYPES>();
		List<Vector2I> keys = new List<Vector2I>(HexEngine._getmoves().Keys);
		Dictionary<MOVE_TYPES, List<Vector2I>> moves = null;
		bool selectedType = false;

		while(allowed.Count < 1)
		{
			CORDS = keys[rng.Next(0, keys.Count)];
			
			moves = HexEngine._getmoves()[CORDS];
			foreach(MOVE_TYPES innerKey in moves.Keys)
				if(moves[innerKey].Count > 0)
					allowed.Add(innerKey);
		}

		while(!selectedType)
		{
			int i = rng.Next(0, allowed.Count);
			MOVE_TYPES testing = allowed[i];
			
			MOVETYPE = (int) testing;
			
			if(moves[testing].Count > 0)
				selectedType = true;
		}

		var movelist = moves[(MOVE_TYPES)MOVETYPE];
		
		MOVEINDEX = rng.Next(0, movelist.Count);
		TO = movelist[MOVEINDEX];
		return;
	}


}
