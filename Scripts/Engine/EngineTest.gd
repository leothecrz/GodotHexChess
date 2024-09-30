class_name EngineTest
extends Node

##
func testSetupTime(ref):
	var tempMarker = Time.get_ticks_usec();
	ref._initDefault();
	print("Setup Time: ", Time.get_ticks_usec() - tempMarker, " milliseconds");
	return;

##
# 9 PAWNS. 8 Have 2 moves. Final has 1.
# 3 BISHOPS. 2 have 2 moves. Final has 8.
# 2 ROOKS. Each have 3 moves.
# 2 KNIGHTS. Each have 4 moves.
# 1 QUEEN. 6 moves.
# 1 KING. 2 moves.
func testMoveGen(ref):
	if(ref.countMoves(ref.legalMoves) == 51):
		return true
	else:
		return false

##
func testCaptureInput2(ref):
	var testPassed = true;
	if (ref.HexBoard[0][-1] != ref.getPieceInt(1, true)):
		testPassed = false;
	ref._makeMove(Vector2i(0,-1), 1, 0, 0);
	if (ref.HexBoard[-1][0] != ref.getPieceInt(1, true)):
		testPassed = false;
	return testPassed;

##
func testCaptureInput(ref):
	var testPassed = true;
	if (ref.HexBoard[0][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	ref._makeMove(Vector2i(0,0), 1, 0, 0);
	if (ref.HexBoard[-1][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	if (testPassed):
		return testCaptureInput2(ref);
	return testPassed;

##
func testMoveInput2(ref):
	var testPassed = true;
	if (ref.HexBoard[-1][-1] != ref.getPieceInt(1, true)):
		testPassed = false;
	ref._makeMove(Vector2i(-1,-1), 2, 0, 0);
	if (ref.HexBoard[-1][1] != ref.getPieceInt(1, true)):
		testPassed = false;
	return [testPassed, testCaptureInput(ref)];

##
func testMoveInput(ref):
	var testPassed = true;
	if (ref.HexBoard[0][1] != ref.getPieceInt(1, false)):
		testPassed = false;
	ref._makeMove(Vector2i(0,1), 0, 0, 0);
	if (ref.HexBoard[0][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	
	if(testPassed): 
		return testMoveInput2(ref);
	return [false, false];

##
func simpleMoveAndCapTest(ref:HexEngine):
	testSetupTime(ref);
	var moveGen = testMoveGen(ref);
	var moveResults = testMoveInput(ref);
	if moveGen : print ("1. Move Gen Passed");
	if moveResults[0] : print ("2. Move Input Passed");
	if moveResults[1] : print ("3. Move Capture Passed");
	ref._resign();
	return;



##
func trymove(depth, ref:HexEngine) -> void:
	if(depth == 0 or ref._getGameOverStatus()):
		return
	var legalmoves = ref._getMoves().duplicate(true);
	for piece in legalmoves.keys():
		for movetype in legalmoves[piece]:
			var index:int = 0;
			for move in legalmoves[piece][movetype]: 
				#logfile.store_string("%v, %s, %v\n" % [piece, ref.MOVE_TYPES.keys()[movetype], move]);
				counter += 1;
				var WAB = ref._duplicateWAB();
				var BAB = ref._duplicateBAB();
				var BP = ref._duplicateBP();
				var InPi = ref._duplicateIP();
				ref._makeMove(piece,movetype,index,ref.PIECES.QUEEN);
				trymove(depth-1,ref);
				ref._undoLastMove(false);
				ref._restoreState(WAB,BAB,BP,InPi,legalmoves);
				index += 1;
	return ;
	
var logfile;
var counter:int;
##
func count_moves(depth:int, ref:HexEngine) -> int:
	#logfile = FileAccess.open("gdlog.txt", FileAccess.WRITE);
	if (depth <= 0):
		return 0;
	counter = 0;
	ref._initDefault();
	trymove(depth, ref);
	ref._resign();
	#logfile.close();
	return counter;

##
func bitboardRangeTest() -> void:
	var radius = 5;
	var failed = false;
	for q:int in range(-radius, radius+1): #[~r, r]
		var negativeQ : int = -1 * q;
		var minRow : int = max(-radius, (negativeQ-radius));
		var maxRow : int = min( radius, (negativeQ+radius));
		for r:int in range(minRow, maxRow+1):
			if(BitBoard.inBitBoardRange(q,r)):
				pass;
			else:
				failed = true;
			pass;
	
	if failed:
		print ("FAILED RANGE TEST");
	else:
		print ("PASSED RANGE TEST");
	
	return;


## Run a test sweep.
func runSweep(ERef:HexEngine):
	
	print("Running Test, Started at: ", Time.get_datetime_string_from_system());
	ERef._t();
	#bitboardRangeTest();
	
	#simpleMoveAndCapTest(ERef);

	#for i in range(1,5):
	var i = 2
	var timeStart = Time.get_ticks_usec();
	print("GD Moves Counted \n Depth %d:" % i, count_moves(i, ERef) );

	#Next Test
	
	print("Total Time Taken: ", Time.get_ticks_usec() - timeStart, " milliseconds");
	return;
