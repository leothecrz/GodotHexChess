using Godot;
using System;
using System.Numerics;
using System.Runtime.CompilerServices;

public partial class AIBase : Node
    {

    private int side;
    private Vector2I TO;
    private Vector2I CORDS;
    private int MOVETYPE;
    private int MOVEINDEX;
    private int PROMOTETO;

    public AIBase(bool playswhite)
    {
        PROMOTETO = (int) HexEngineSharp.PIECES.QUEEN;
        side = 0;
        if ( playswhite ) side = 1;
        return;
    }

    
    // GETTER

    
    public Vector2I _getCords()
    {
        return CORDS;
    }

    public int _getMoveType()
    {
        return MOVETYPE;
    }

    
    public int _getMoveIndex()
    {
        return MOVEINDEX;
    }

    public int _getPromoteTo()
    {
        return PROMOTETO;
    }

    public Vector2I _getTo()
    {
        return TO;
    }

    public void _makeChoice(HexEngineSharp HexEngine)
    {
        return;
    }
}
