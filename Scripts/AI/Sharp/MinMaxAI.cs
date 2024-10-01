using Godot;
using System;

using HexChess;
using static HexChess.HexConst;
using System.ComponentModel.DataAnnotations.Schema;

public partial class MinMaxAI : AIBase
{

	private int maxDepth;
	
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


