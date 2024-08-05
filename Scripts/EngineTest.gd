class_name EngineTest
extends Node

##
func testSetupTime(ref):
	var tempMarker = Time.get_ticks_usec();
	ref._initDefault();
	print("Setup Time: ", Time.get_ticks_usec() - tempMarker, " milliseconds");

##
func testMoveGen(ref):
	if(ref.countMoves(ref.legalMoves) == 51):
		print("Default Move Gen SUCCEDED");
	else:
		print("Default Move Gen FAILED");

## Run a test sweep.
func runSweep(EngineRef:HexEngine):
	var timeStart = Time.get_ticks_usec();
	print("Running Test, Started at: ", Time.get_datetime_string_from_system());
	
	testSetupTime(EngineRef);
	testMoveGen(EngineRef);
	
	print("Total Time Taken: ", Time.get_ticks_usec() - timeStart, " milliseconds");
	return;
