
using System;
using System.Collections.Generic;

namespace HexChess
{
	public class Bitboard128 
	{
		public const int INDEX_TRANSITION = 62;
		public const int INDEX_OFFSET = 63;

		public static readonly int[] COLUMN_SIZES = {6, 7, 8, 9, 10, 11, 10, 9, 8, 7, 6};
		public static readonly int[] COLUMN_MIN_R = {0, -1, -2, -3, -4, -5, -5, -5, -5, -5, -5};
		public static readonly int[] COLUMN_MAX_R = {5, 5, 5, 5, 5, 5, 4, 3, 2, 1, 0};

		public ulong Front {get; private set;} 
		public ulong Back {get; private set;}


		//Statics


		/// <summary>
		/// Create a bitboard with the bit at index set to '1'.
		/// </summary>
		/// <param name="index"> Index of bit to be set to on </param>
		/// <returns> A new bitboard with the bit at index set to on. </returns>
		public static Bitboard128 OneBitAt (int index)
		{
			ulong back;
			ulong front = 0;
			if(index > Bitboard128.INDEX_TRANSITION)
			{
				front = TwoPowerN( index - Bitboard128.INDEX_OFFSET );
				back = 0;
			}
			else
				back = TwoPowerN( index );
				
			return new Bitboard128(front,back);
		}
		/// <summary>
		/// Using an OR combine all the bitboards into one. Create and return the Bitwise-OR total of all BB
		/// </summary>
		/// <param name="BBArray">Bitboards to combine</param>
		/// <returns></returns>
		public static Bitboard128 ORCombine (Bitboard128[] BBArray)
		{
			Bitboard128 returnBoard = new Bitboard128(0,0);
			Bitboard128 tempBoard;
			
			foreach (Bitboard128 BB in BBArray){
				tempBoard = returnBoard.OR(BB);
				returnBoard = tempBoard;
			}
			return returnBoard;
		}
		/// <summary>
		/// Check if (Q,R) are legal for a r=5 board.
		/// </summary>
		/// <param name="qpos"></param>
		/// <param name="rpos"></param>
		/// <returns></returns>
		public static bool IsLegalHexCords(int qpos, int rpos)
		{
			return (-5 <= qpos) && (qpos <= 5) && (COLUMN_MIN_R[qpos + 5] <= rpos) && (rpos <= COLUMN_MAX_R[qpos + 5]);
		}

		/// <summary> Quick Powers of 2.  </summary>
		/// <param name="n"> N must be greater than -1. N must be below 65 </param>
		/// <returns> 2^n </returns>
		public static ulong TwoPowerN (int n)
		{
			return ((ulong) 1) << n;
		}
		

		// BB


		public Bitboard128(int Front = 0 , int Back = 0)
		{
			this.Front = (ulong) Front;
			this.Back = (ulong) Back;
		}
		public Bitboard128(ulong Front = 0 , ulong Back = 0)
		{
			this.Front = Front;
			this.Back = Back;
		}
		public Bitboard128(List<int> indexlist)
		{
			this.Front = 0;
			this.Back = 0;
			foreach(var i in indexlist)
			{
				if(i > Bitboard128.INDEX_TRANSITION)
					this.Front |= TwoPowerN( i - Bitboard128.INDEX_OFFSET );
				else
					this.Back |= TwoPowerN( i );
			}
		}

		public Bitboard128 XOR(Bitboard128 to)
		{
			return new Bitboard128(Front ^ to.Front, Back ^ to.Back);
		}
		public Bitboard128 OR(Bitboard128 to)

		{
			return new Bitboard128(Front | to.Front, Back | to.Back);
		}
		public Bitboard128 AND(Bitboard128 to)
		{
			return new Bitboard128(Front & to.Front, Back & to.Back);
		}
		/// <summary>
		/// Flip all the bits on the bitboard
		/// </summary>
		/// <returns></returns>
		public Bitboard128 FLIP()
		{
			return new Bitboard128(~Front, ~Back);
		}


		// UTIL


		/// <summary> Determines whether the specified bitboard is equal to the current bitboard. </summary>
		/// <param name="to"></param>
		/// <returns> true if the bitboard object is equal to the current bitboard; otherwise, false </returns>
		public bool EQUAL(Bitboard128 to)
		{
			return ((Front ^ to.Front) == 0) && ((Back ^ to.Back) == 0);
		}
		/// <summary></summary><returns>True - if all bits are off. False - at least one bit is on</returns>
		public bool Empty()
		{
			return (Back == 0) && (Front == 0);
		}
		
		/// <summary> Create a copy of current bitboard </summary>
		/// <returns> A copy of current </returns>
		public Bitboard128 Copy()
		{
			return new Bitboard128(Front, Back);
		}
		
		/// <summary> Create a List object holding the indexes of all on bits of the current bitboard. </summary>
		/// <returns> List of all indexes </returns>
		public List<int> ExtractIndexes()
		{
			ulong b = Back;
			ulong f = Front;
			List<int> indexes = new ();
			int index = 0;
			while(b > 0b0)
			{
				if ((b & 0b1) > 0)
					indexes.Add(index);
				b >>= 1;
				index += 1;
			}
			index = INDEX_OFFSET;
			while(f > 0b0)
			{
				if ((f & 0b1) > 0)
					indexes.Add(index);
				f >>= 1;
				index += 1;
			}
			return indexes;
		}


		//String


		public override String ToString()
		{
			string frontBinary = Convert.ToString((long)Front, 2).PadLeft(32, '0');
			string backBinary = Convert.ToString((long)Back, 2).PadLeft(INDEX_OFFSET, '0');
			return $"{frontBinary} {backBinary}";
		}
		/// <summary>
		/// Return a string representation of the object. In Ints written out.
		/// </summary>
		/// <returns></returns>
		public String ToStringNonBin()
		{
			return $"{Front} {Back}";
		}


	}
}