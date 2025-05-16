
using Godot;
using static HexChess.HexConst;

namespace HexChess
{

public class HexTester
{

	HexEngineSharp referenceSharp;

	public HexTester(HexEngineSharp refernce)
	{
		referenceSharp = refernce;
	}


	public void runFullSuite()
	{
		for (int i = 1; i <= 3; i++)
		{
			countTo(i);
		}
	}

	public void countTo(int i)
	{
		GD.Print("HexEngineSharp Count Test");
		GD.Print($"Moves to depth {i}: {count_moves(i)}, took {totalTime} microseconds.");
	}

	private void trymove(int depth)
	{
		if(depth == 0 || referenceSharp._getGameOverStatus())
		{
			return;
		}
		var snap = referenceSharp._snapshotState();
		var legalmoves = snap.filteredMoves;
		foreach( Vector2I piece in legalmoves.Keys)
		{
			foreach(MOVE_TYPES movetype in legalmoves[piece].Keys)
			{
				int index = 0;
				foreach(Vector2I move in legalmoves[piece][movetype])
				{
					counter += 1;

					var stamp = Time.GetTicksUsec();
					referenceSharp._makeMove(piece, movetype, index, PIECES.QUEEN);
					totalTime += Time.GetTicksUsec() - stamp;

					trymove(depth-1);
					referenceSharp._undoLastMove(false);
					referenceSharp._restoreSnapshot(snap);
					
				}
			}
		}
		return;
	}	

	private int counter;
	private ulong totalTime;

	private int count_moves(int depth)
	{
		if (depth <= 0)
			return 0;
		counter = 0;
		totalTime = 0;
		referenceSharp.InitiateDefault();
		trymove(depth);
		referenceSharp._resign();
		return counter;
	}

}


}