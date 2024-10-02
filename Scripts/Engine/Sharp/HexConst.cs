using System;
using System.Collections.Generic;
using System.Linq;
using Godot;

namespace HexChess
{
	public class HexConst
	{
	// ENUMS
	public enum PIECES {ZERO, PAWN, KNIGHT, ROOK, BISHOP, QUEEN, KING};
	public enum SIDES {BLACK, WHITE};
	public enum MOVE_TYPES {MOVES, CAPTURE, ENPASSANT, PROMOTE};
	public enum MATE_STATUS {NONE, CHECK, OVER};
	public enum UNDO_FLAGS {NONE, ENPASSANT, CHECK, GAME_OVER };
	public enum ENEMY_TYPES { PLAYER_TWO, RANDOM, MIN_MAX, NN }

	//	Defaults
	public const int KING_INDEX = 0;
	public const int HEX_BOARD_RADIUS = 5;
	public const int DECODE_FEN_OFFSET = 70;
	public const int TYPE_MASK = 0b0111;

	//	Vectors
	public static readonly Dictionary<string,Vector2I> ROOK_VECTORS = new Dictionary<string, Vector2I> { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0) } };
	public static readonly Dictionary<string,Vector2I> BISHOP_VECTORS = new Dictionary<string, Vector2I> { { "lfoward", new Vector2I(-2,1)}, { "rFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "lbackward", new Vector2I(1,1)}, { "rBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
	public static readonly Dictionary<string,Vector2I> KING_VECTORS = new Dictionary<string, Vector2I> { { "foward", new Vector2I(0,-1)}, { "lFoward", new Vector2I(-1,0)}, { "rFoward", new Vector2I(1,-1)}, { "backward", new Vector2I(0,1)}, { "lBackward", new Vector2I(-1,1)}, { "rBackward", new Vector2I(1,0)}, { "dlfoward", new Vector2I(-2,1)}, { "drFoward", new Vector2I(-1,-1)}, { "left", new Vector2I(-1,2)}, { "dlbackward", new Vector2I(1,1)}, { "drBackward", new Vector2I(2,-1)}, { "right", new Vector2I(1,-2) } };
	public static readonly Dictionary<string,Vector2I> KNIGHT_VECTORS = new Dictionary<string, Vector2I> { { "left", new Vector2I(-1,-2)}, { "lRight", new Vector2I(1,-3)}, { "rRight", new Vector2I(2,-3)} };
	
	//	Templates
	public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> DEFAULT_MOVE_TEMPLATE = new Dictionary<MOVE_TYPES, List<Vector2I>> { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I>{}},  };
	public static readonly Dictionary<MOVE_TYPES, List<Vector2I>> PAWN_MOVE_TEMPLATE = new Dictionary<MOVE_TYPES, List<Vector2I>> { {MOVE_TYPES.MOVES, new List<Vector2I> {}}, {MOVE_TYPES.CAPTURE, new List<Vector2I> {}}, {MOVE_TYPES.ENPASSANT, new List<Vector2I> {}}, {MOVE_TYPES.PROMOTE, new List<Vector2I> {}} };
	public static readonly int[] PAWN_START 	= {-4, -3, -2, -1, 0, 1, 2, 3, 4};
	public static readonly int[] PAWN_PROMOTE 	= {-5, -4, -3, -2, -1, 0, 1, 2 , 3, 4};
	public static readonly int[] KNIGHT_MULTIPLERS = {-1, 1, -1, 1};


	public static int QRToIndex (int q, int r)
	{
		int normalq = q + 5;
		int i = 0;
		int index = 0;
		foreach(int size in Bitboard128.COLUMN_SIZES)
		{
			if (normalq == i)
				break; 
			index += size;
			i += 1;
		}
		
		if(q <= 0)
			index += 5 - r;
		else
			index += (Bitboard128.COLUMN_SIZES[normalq]-6) - r;
				
		return index;
	}
	public static Vector2I IndexToQR (int index){
		int accumulated_index = 0;
		int normalq = 0;
		int r;
		
		foreach (int size in Bitboard128.COLUMN_SIZES)
		{
			if( accumulated_index + size > index ) break;
			accumulated_index += size;
			normalq += 1;
		}
		
		if( normalq <= 5 )
			r = 5 - (index - accumulated_index);
		else
			r = (Bitboard128.COLUMN_SIZES[normalq] - 6) - (index - accumulated_index);
		
		var q = normalq - 5;
		return new Vector2I(q, r);
	}
	public static int getSAxialCordFrom(Vector2I cords)
	{
		return (-1 * cords.X) - cords.Y;
	}
	public static int getAxialCordDist(Vector2I from, Vector2I to)
	{
		var dif = new Vector3I(from.X-to.X, from.Y-to.Y, getSAxialCordFrom(from)-getSAxialCordFrom(to));
		return Math.Max( Math.Max( Math.Abs(dif.X), Math.Abs(dif.Y)), Math.Abs(dif.Z));
	}
	public static void printActivePieces(Dictionary<PIECES, List<Vector2I>>[]AP)
	{
		for (int side = 0; side < AP.Length; side += 1)
		{
			GD.Print(Enum.GetNames(typeof (SIDES)).GetValue(side));
			foreach(PIECES piece in AP[side].Keys)
				GD.Print(Enum.GetName(typeof(PIECES), piece), " : ", AP[side][piece]);
			GD.Print("\n");
		}
	}
	// set all values of given board to zero.
	public static void resetBoard(Dictionary<int, Dictionary<int,int>> board)
	{
		foreach( int key in board.Keys)
			foreach( int innerKey in board[key].Keys)
				board[key][innerKey] = 0;
		return;
	}
	// Count the amount of moves found
	public static int countMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> movesList)
	{
		int count = 0;
		foreach( Vector2I piece in movesList.Keys )
			foreach ( MOVE_TYPES moveType in movesList[piece].Keys )
				foreach ( Vector2I move in movesList[piece][moveType])
					count += 1;
		return count;
	}
	// Find Intersection Of Two Arrays. O(N^2)
	public static T[] intersectOfTwoArrays<T>(T[] ARR, T[] ARR1)
	{
		List<T> intersection = new List<T>();
		foreach( T item in ARR)
			if (Array.Exists(ARR1, e => e.Equals(item)))
				intersection.Add(item);
		return intersection.ToArray();
	}
	public static List<T> intersectOfTwoList<T>(List<T> ARR, List<T> ARR1)
	{
		return ARR.Intersect(ARR1).ToList<T>();
	}
	// Find Items Unique Only To ARR. O(N^2)
	public static T[] differenceOfTwoArrays<T>(T[] ARR, T[] ARR1)
	{
		List<T> diff = new List<T>();
		foreach( T item in ARR)
			if (!Array.Exists(ARR1, e => e.Equals(item)))
				diff.Add(item);
		return diff.ToArray();
	}
	public static List<T> differenceOfTwoList<T>(List<T> ARR, List<T> ARR1)
	{
		// T[] diffArray = differenceOfTwoArrays(ARR.ToArray(), ARR1.ToArray() )
		// return new List<T> (diffArray);
		return ARR.Except(ARR1).ToList();
	}
	public static void printBoard(Dictionary<int, Dictionary<int, int>> board)
    {
        // Get the keys of the board and reverse them
        var flippedKeys = board.Keys.ToList();
        flippedKeys.Reverse();

        // Loop through each row
        foreach (var key in flippedKeys)
        {
            // Prepare a string list to build the row output
            List<string> rowString = new List<string>();

            // Calculate the offset and pad the row with spaces
            int offset = 12 - board[key].Count;
            for (int i = 0; i < offset; i++)
            {
                rowString.Add("  ");
            }

            // Loop through the inner dictionary (columns)
            foreach (var innerKey in board[key].Keys)
            {
                // If the board value is 0, append empty spaces; otherwise, format the value
                if (board[key][innerKey] == 0)
                {
                    rowString.Add("   "); // Empty space
                }
                else
                {
                    rowString.Add(string.Format(" {0:00}", board[key][innerKey])); // Format with leading zeros
                }
                rowString.Add(", ");
            }

            // Print the row
            Console.WriteLine();
            Console.WriteLine(string.Join("", rowString));
            Console.WriteLine();
        }
    }


	// Get int representation of piece.
	public static int getPieceInt(PIECES piece, bool isBlack)
	{
		int id = (int) piece;
		if(!isBlack)
			id += 8;
		return id;
	}
	// Strip the color bit information and find what piece is in use.
	public static PIECES getPieceType(int id)
	{
		int res = (id & TYPE_MASK);
		return (PIECES) res;
	}
	public static bool charIsInt(char activeChar)
	{
		return ('0' <= activeChar) && (activeChar <= '9');
	}
	public static Dictionary<MOVE_TYPES, List<Vector2I>> DeepCopyMoveTemplate(Dictionary<MOVE_TYPES, List<Vector2I>> original)
	{
		var copy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
		foreach (var kvp in original)
		{
			var newList = new List<Vector2I>(kvp.Value);
			copy.Add(kvp.Key, newList);
		}
		return copy;
	}
	public static Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> DeepCopyLegalMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> original)
	{
		var copy = new Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>>();
		foreach (var kvp in original)
		{
			var innerDictionaryCopy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
			foreach (var innerKvp in kvp.Value)
			{
				var newList = new List<Vector2I>(innerKvp.Value);
				innerDictionaryCopy.Add(innerKvp.Key, newList);
			}
			copy.Add(kvp.Key, innerDictionaryCopy);
		}
		return copy;
	}
	public static Dictionary<MOVE_TYPES, List<Vector2I>> DeepCopyInnerDictionary(
		Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves,
		Vector2I key)
	{
		if (!legalMoves.TryGetValue(key, out var innerDictionary))
			return null;
		
		var innerDictionaryCopy = new Dictionary<MOVE_TYPES, List<Vector2I>>();
		foreach (var kvp in innerDictionary)
		{
			var newList = new List<Vector2I>(kvp.Value);
			innerDictionaryCopy.Add(kvp.Key, newList);
		}
		return innerDictionaryCopy;
	}
	public static void PrettyPrintLegalMoves(Dictionary<Vector2I, Dictionary<MOVE_TYPES, List<Vector2I>>> legalMoves)
	{
		// Check if the dictionary is null or empty
		if (legalMoves == null || legalMoves.Count == 0)
		{
			GD.Print("null");
			return;
		}

		string outstring = "";

		// Iterate through the outer dictionary (keys are Vector2I, values are inner dictionaries)
		foreach (var outerKvp in legalMoves)
		{
			var outerKey = outerKvp.Key; // Vector2I
			var innerDictionary = outerKvp.Value; // Dictionary<MOVE_TYPES, List<Vector2I>>

			// Start the print of the outer dictionary in the specified format
			outstring += $"({FormatVector2I(outerKey)}): {{ ";

			// Iterate through the inner dictionary (keys are MOVE_TYPES, values are lists of Vector2I)
			foreach (var innerKvp in innerDictionary)
			{
				var moveType = innerKvp.Key; // MOVE_TYPES
				var vectorList = innerKvp.Value; // List<Vector2I>

				// Print the MoveType and the list of Vector2I in the required format
				outstring += $"{(int)moveType}: [{FormatVector2IList(vectorList)}], ";
			}
			outstring = outstring.Substr(0, outstring.Length-2);
			// Close the outer dictionary print
			outstring += " }, ";
		}
		GD.Print("{ ", outstring, "}");
	}
	private static string FormatVector2I(Vector2I vector)
	{
		return $"{vector.X}, {vector.Y}";
	}
	private static string FormatVector2IList(List<Vector2I> vectorList)
	{
		if (vectorList == null || vectorList.Count == 0) return "";
		return string.Join(", ", vectorList.Select(v => $"({FormatVector2I(v)})"));
	}

	}
}