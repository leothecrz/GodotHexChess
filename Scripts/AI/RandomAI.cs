using Godot;
using System;

public partial class RandomAI : AIBase
{

	 public RandomAI(bool playswhite)
    {
        PROMOTETO = (int) HexEngineSharp.PIECES.QUEEN;
        side = playswhite ? 1 : 0;
        return;
    }

	public override void _makeChoice(HexEngineSharp HexEngine)
	{
		
		return;
	}


}
