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
# 3 BISHOPS
# 2 ROOKS.
# 2 KNIGHTS
# 1 QUEEN
# 1 KING
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
	ref._makeMove(Vector2i(0,-1), "Capture", 0, 0);
	if (ref.HexBoard[-1][0] != ref.getPieceInt(1, true)):
		testPassed = false;
	return testPassed;

##
func testCaptureInput(ref):
	var testPassed = true;
	if (ref.HexBoard[0][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	ref._makeMove(Vector2i(0,0), "Capture", 0, 0);
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
	ref._makeMove(Vector2i(-1,-1), "EnPassant", 0, 0);
	if (ref.HexBoard[-1][1] != ref.getPieceInt(1, true)):
		testPassed = false;
	return [testPassed, testCaptureInput(ref)];

##
func testMoveInput(ref):
	var testPassed = true;
	if (ref.HexBoard[0][1] != ref.getPieceInt(1, false)):
		testPassed = false;
	ref._makeMove(Vector2i(0,1), "Moves", 0, 0);
	if (ref.HexBoard[0][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	
	if(testPassed): 
		return testMoveInput2(ref);
	return [false, false];

##
func testMoveAndCaptures(ref):
	testSetupTime(ref);
	var moveGen = testMoveGen(ref);
	var moveResults = testMoveInput(ref);
	if moveGen : print ("1. Move Gen Passed");
	if moveResults[0] : print ("2. Move Input Passed");
	if moveResults[1] : print ("3. Move Capture Passed");
	return;



## Run a test sweep.
func runSweep(ERef:HexEngine):
	var timeStart = Time.get_ticks_usec();
	print("Running Test, Started at: ", Time.get_datetime_string_from_system());
	
	testMoveAndCaptures(ERef);
	
	print("Total Time Taken: ", Time.get_ticks_usec() - timeStart, " milliseconds");
	return;
