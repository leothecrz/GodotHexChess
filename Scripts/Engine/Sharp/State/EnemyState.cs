
using Godot;

using static HexChess.HexConst;

namespace HexChess
{
    public class EnemyState
    {
		
		// Enemy
		public AIBase EnemyAI {get; set;} = null;
		public ENEMY_TYPES EnemyType {get; set;} = ENEMY_TYPES.PLAYER_TWO;
		public PIECES EnemyPromotedTo {get; set;} = PIECES.ZERO;

		// Enemy Bool
		public bool EnemyIsAI {get; set;} = false;
		public bool EnemyPlaysWhite {get; set;} = false;
		public bool EnemyPromoted {get; set;} =  false;

		// ENemy Info
		public PIECES EnemyChoiceType {get; set;}
		public int EnemyChoiceIndex {get; set;}
		public Vector2I EnemyTo {get; set;}


		public EnemyState()
		{
			
		}

    }
}