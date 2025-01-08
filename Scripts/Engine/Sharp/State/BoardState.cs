
using System.Collections.Generic;
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
public class BoardState
{
	// Captures
	/// <summary> Tracks captures made by side B. </summary>
	public List<PIECES> BlackCaptures {get; set;}
	/// <summary> Tracks captures made by side W. </summary>
	public List<PIECES> WhiteCaptures {get; set;}
	/// <summary> Last turn's capture type. </summary>
	public PIECES CaptureType {get; set;} = PIECES.ZERO;
	/// <summary> Last turn's capture index. Position in active pieces. </summary>
	public int CaptureIndex {get; set;} = -1;
	/// <summary> Signals if last turn had a capture </summary>
	public bool CaptureValid {get; set;} = false;

	//EnPassant
	/// <summary> Last turn's EnPassant Cordinates. </summary>
	public Vector2I EnPassantCords {get; set;}
	/// <summary> Last turn's Enpassant's Target Cordinates. </summary>
	public Vector2I EnPassantTarget {get; set;}
	/// <summary> Signals if last turn had an Enpassant move. </summary>
	public bool EnPassantCordsValid {get; set;} = false;
 
	// Check & Over
	/// <summary>
	/// 
	/// </summary>
	//public Vector2I GameInCheckFrom {get; set;}
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
		//GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
		UndoTo 			= new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
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
	/// Reset the turn flags and set the over flag to false.
	/// </summary>
	public void resetState()
	{
		ResetTurnFlags();
		IsOver = false;
		//GameInCheckFrom = new Vector2I(HEX_BOARD_RADIUS+1,HEX_BOARD_RADIUS+1);
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