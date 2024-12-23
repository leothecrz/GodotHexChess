
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
		var legalmoves = DeepCopyLegalMoves(referenceSharp.GetMoves());
		foreach( Vector2I piece in legalmoves.Keys)
		{
			foreach(MOVE_TYPES movetype in legalmoves[piece].Keys)
			{
				int index = 0;
				foreach(Vector2I move in legalmoves[piece][movetype])
				{
					
					// using (StreamWriter writer = new StreamWriter(path, append: true))
					// {
					//  	writer.WriteLine($"{piece}, {movetype}, {move}");
					// }
					counter += 1;
					var WAB = referenceSharp._duplicateWAB();
					var BAB = referenceSharp._duplicateBAB();
					var BP = referenceSharp._duplicateBP();
					var InPi = referenceSharp._duplicateIP();

					var stamp = Time.GetTicksUsec();
					referenceSharp._makeMove(piece, movetype, index, PIECES.QUEEN);
					totalTime += Time.GetTicksUsec() - stamp;

					trymove(depth-1);
					referenceSharp._undoLastMove(false);
					referenceSharp._restoreState(WAB,BAB,BP,InPi,legalmoves);
					
				}
			}
		}
		return ;
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