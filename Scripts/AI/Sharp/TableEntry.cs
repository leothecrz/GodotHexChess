
namespace HexChess
{
    public class TableEntry
    {
        public enum ENTRY_TYPE {EXACT, LOWER, UPPER};

        public long value {get; private set;} 
        public int depth {get; private set;}
        public ENTRY_TYPE type {get; private set;}
        
        public TableEntry(long val, int dep, ENTRY_TYPE t)
		{	
            value = val;
            depth = dep;
            type = t;
            return;
		}


    }
}