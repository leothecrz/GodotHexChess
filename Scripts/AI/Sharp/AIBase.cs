using Godot;
namespace HexChess
{
	public abstract class AIBase
	{

		protected int side;
		protected Vector2I TO;
		protected Vector2I CORDS;
		protected int MOVETYPE;
		protected int MOVEINDEX;
		protected int PROMOTETO;

		// GETTERS

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

		//REQUIRED

		public abstract void _makeChoice(HexEngineSharp HexEngine);
	}		
}