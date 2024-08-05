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
	return;

func testMoveInput2(ref):
	var testPassed = true;
	if (ref.HexBoard[-1][0] != ref.getPieceInt(1, true)):
		testPassed = false;
	ref._makeMove(Vector2i(1,1), "EnPassant", 0, 0);
	if (ref.HexBoard[1][0] != ref.getPieceInt(1, true)):
		testPassed = false;
	
	return testPassed;

##
func testMoveInput(ref):
	var testPassed = true;
	if (ref.HexBoard[1][1] != ref.getPieceInt(1, false)):
		testPassed = false;
	ref._makeMove(Vector2i(1,1), "Moves", 0, 0);
	if (ref.HexBoard[1][0] != ref.getPieceInt(1, false)):
		testPassed = false;
	
	if(testPassed): 
		return testMoveInput2(ref);
	return false;

## Run a test sweep.
func runSweep(ERef:HexEngine):
	var timeStart = Time.get_ticks_usec();
	print("Running Test, Started at: ", Time.get_datetime_string_from_system());
	
	var setup = testSetupTime(ERef);
	var moveGen = testMoveGen(ERef);
	var moveInput = testMoveInput(ERef);
	
	print("Total Time Taken: ", Time.get_ticks_usec() - timeStart, " milliseconds");
	
	if setup : print ("Default Setup Passed")
	
	
	return;
