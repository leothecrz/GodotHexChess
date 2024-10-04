
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
    public class BoardState
{
    //EnPassant

    public Vector2I EnPassantCords {get; set;} = new Vector2I(-HEX_BOARD_RADIUS, -HEX_BOARD_RADIUS);
	public Vector2I EnPassantTarget {get; set;} = new Vector2I(HEX_BOARD_RADIUS, HEX_BOARD_RADIUS);
	public bool EnPassantCordsValid {get; set;}  = false;
    
    // Check & Over
    public bool isOver {get; set;} = false;
    public bool isCheck {get; set;} = false;

    //Turns

    public bool isWhiteTurn {get; set;} = false;
    public int turnNumber {get; set;} = 0;


    public BoardState()
    {

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


}
}