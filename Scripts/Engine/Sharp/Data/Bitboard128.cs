
using System;
using System.Collections.Generic;

namespace HexChess
{
	public class Bitboard128 
	{
		public const int INDEX_TRANSITION = 62;
		public const int INDEX_OFFSET = 63;

		public static readonly int[] COLUMN_SIZES = {6,7,8,9,10,11,10,9,8,7,6};
		public static readonly int[] COLUMN_MIN_R = {0, -1, -2, -3, -4, -5, -5, -5, -5, -5, -5};
		public static readonly int[] COLUMN_MAX_R = {5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0};

		private ulong front;
		private ulong back;

		/* QUICK Powers of 2
		N must be below 65 */
		public static ulong get2PowerN (int n)
		{
			return ((ulong) 1) << n;
		}
		public static Bitboard128 createSinglePieceBB (int index)
		{
			ulong back;
			ulong front = 0;
			if(index > Bitboard128.INDEX_TRANSITION)
			{
				front = get2PowerN( index - Bitboard128.INDEX_OFFSET );
				back = 0;
			}
			else
				back = get2PowerN( index );
				
			return new Bitboard128(front,back);
		}
		// Create and return the Bitwise-OR total of all BB
		public static Bitboard128 genTotalBitBoard (Bitboard128[] BBArray)
		{
			Bitboard128 returnBoard = new Bitboard128(0,0);
			Bitboard128 tempBoard;
			
			foreach (Bitboard128 BB in BBArray){
				tempBoard = returnBoard.OR(BB);
				returnBoard = tempBoard;
			}
			return returnBoard;
		}
		public static bool inBitboardRange(int qpos, int rpos)
		{
			return ( (-5 <= qpos) && (qpos <= 5) && (Bitboard128.COLUMN_MIN_R[qpos + 5] <= rpos) && (rpos <= Bitboard128.COLUMN_MAX_R[qpos + 5] ) );
		}
		public Bitboard128(int Front = 0 , int Back = 0)
		{
			front = (ulong) Front;
			back = (ulong) Back;
		}

		public Bitboard128(ulong Front = 0 , ulong Back = 0)
		{
			front = Front;
			back = Back;
		}

		public ulong _getF()
		{
			return front;
		}
		public ulong _getB(){
			return back;
		}
		public Bitboard128 XOR(Bitboard128 to)
		{
			return new Bitboard128(front ^ to._getF(), back ^ to._getB());
		}
		public Bitboard128 OR(Bitboard128 to)

		{
			return new Bitboard128(front | to._getF(), back | to._getB());
		}
		public Bitboard128 AND(Bitboard128 to)
		{
			return new Bitboard128(front & to._getF(), back & to._getB());
		}
		public bool EQUAL(Bitboard128 to)
		{
			return ((front ^ to._getF()) == 0) && ((back ^ to._getB()) == 0);
		}
		public bool IS_EMPTY()
		{
			return (back == 0) && (front == 0);
		}
		public Bitboard128 _getCopy()
		{
			return new Bitboard128(_getF(), _getB());
		}
		public List<int> _getIndexes()
		{
			ulong b = _getB();
			ulong f = _getF();
			List<int> indexes = new List<int> {};
			int index = 0;
			while(b > 0b0){
				if ((b & 0b1) > 0)
					indexes.Add(index);
				b >>= 1;
				index += 1;
			}
			index = 63;
			while(f > 0b0){
				if ((f & 0b1) > 0)
					indexes.Add(index);
				f >>= 1;
				index += 1;
			}
			return indexes;
		}
		public override string ToString()
		{
			string frontBinary = Convert.ToString((long)front, 2).PadLeft(32, '0');
			string backBinary = Convert.ToString((long)back, 2).PadLeft(INDEX_OFFSET, '0');
			return $"{frontBinary} {backBinary}";
		}
		public String ToStringNonBin()
		{
			return $"{front} {back}";
		}

	}
}