
using System;
using System.Collections.Generic;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
    public class BoardState
{
	// Captures
	public List<PIECES> blackCaptures {get; set;}
	public List<PIECES> whiteCaptures {get; set;}

	public PIECES captureType {get; set;}  = PIECES.ZERO;
	public int captureIndex {get; set;}  = -1;
	public bool captureValid {get; set;}   = false;

    //EnPassant
    public Vector2I EnPassantCords {get; set;} = new Vector2I(-HEX_BOARD_RADIUS, -HEX_BOARD_RADIUS);
	public Vector2I EnPassantTarget {get; set;} = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
	public bool EnPassantCordsValid {get; set;}  = false;
    
    // Check & Over
	public Vector2I GameInCheckFrom {get; set;} = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
    public bool isOver {get; set;} = false;
    public bool isCheck {get; set;} = false;

    //Turns
    public bool isWhiteTurn {get; set;} = false;
    public int turnNumber {get; set;} = 0;


	// UndoFlags and Data
	public bool uncaptureValid {get; set;} = false;
	public bool unpromoteValid {get; set;}   = false;
	public PIECES unpromoteType {get; set;} = PIECES.ZERO;
	public int unpromoteIndex {get; set;}  = -1;
	public PIECES undoType {get; set;} = PIECES.ZERO;
	public int undoIndex {get; set;} = -1;
	public Vector2I undoTo {get; set;} = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);



    public BoardState()
    {
		blackCaptures = new List<PIECES>();
		whiteCaptures = new List<PIECES>();
    }

    public void incrementTurnNumber()
	{
		turnNumber += 1;
		return;
	}

	public void decrementTurnNumber()
	{
		turnNumber -= 1;
		return;
	}

	public void swapPlayerTurn()
	{
		isWhiteTurn = !isWhiteTurn;
		return;
	}

	public void nextTurn()
	{
		swapPlayerTurn();
		incrementTurnNumber();
	}

	public void resetTurnFlags()
	{
		isCheck = false;
		captureValid = false;
		EnPassantCordsValid = false;
		return;
	}

}
}