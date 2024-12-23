
using System;
using System.Collections.Generic;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
    public class BoardState
{
	// Captures
	public List<PIECES> BlackCaptures {get; set;}
	public List<PIECES> WhiteCaptures {get; set;}

	public PIECES CaptureType {get; set;} = PIECES.ZERO;
	public int CaptureIndex {get; set;} = -1;
	public bool CaptureValid {get; set;} = false;

	//EnPassant
	public Vector2I EnPassantCords {get; set;}
	public Vector2I EnPassantTarget {get; set;}
	public bool EnPassantCordsValid {get; set;} = false;
 
	// Check & Over
	public Vector2I GameInCheckFrom {get; set;}
	public bool IsOver {get; set;} = false;
	public bool IsCheck {get; set;} = false;
	public bool CheckByMany {get; set;} = false;

	//Turns
	public bool IsWhiteTurn {get; set;} = false;
	public int TurnNumber {get; set;} = 0;


	// UndoFlags and Data
	public Vector2I UndoTo {get; set;}
	public PIECES UnpromoteType {get; set;} = PIECES.ZERO;
	public PIECES UndoType {get; set;} = PIECES.ZERO;
	public int UnpromoteIndex {get; set;}  = -1;
	public int UndoIndex {get; set;} = -1;
	public bool UncaptureValid {get; set;} = false;
	public bool UnpromoteValid {get; set;}   = false;
	
	/// <summary>
	/// Board state
	/// </summary>
    public BoardState()
    {
		BlackCaptures = new List<PIECES>();
		WhiteCaptures = new List<PIECES>();
		EnPassantCords  = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
		EnPassantTarget = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
		GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
		UndoTo 			= new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
    }
	/// <summary>
	/// increment the turn number
	/// </summary>
    public void IncrementTurnNumber()
	{
		TurnNumber += 1;
		return;
	}
	/// <summary>
	/// decrement the turn number
	/// </summary>
	public void DecrementTurnNumber()
	{
		TurnNumber -= 1;
		return;
	}
	/// <summary>
	/// Flip the iswhiteturn boolean
	/// </summary>
	public void SwapPlayerTurn()
	{
		IsWhiteTurn = !IsWhiteTurn;
		return;
	}
	/// <summary>
	/// Reset the InCheck, CaptureValid, and EnPassantValid flags.
	/// </summary>
	public void ResetTurnFlags()
	{
		IsCheck = false;
		CheckByMany = false;
		CaptureValid = false;
		EnPassantCordsValid = false;
		return;
	}
	/// <summary>
	/// Swap the player turn and increment the turn number.
	/// </summary>
	public void NextTurn()
	{
		SwapPlayerTurn();
		IncrementTurnNumber();
	}
	/// <summary>
	/// Swap the player turn and decrement the turn number. Reset the undo flags. 
	/// </summary>
	public void LastTurn()
	{
		UncaptureValid = false;
		UnpromoteValid = false;
		DecrementTurnNumber();
		SwapPlayerTurn();
	}
}
}