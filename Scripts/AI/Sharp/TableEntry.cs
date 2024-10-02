
namespace HexChess
{
    public class TableEntry
    {
        public enum ENTRY_TYPE {EXACT, LOWER, UPPER};
        
        public int value {get; private set;} 
        public int depth {get; private set;}
        public ENTRY_TYPE type {get; private set;}
        
        ##
        func _init(val:int, dep:int, t:int):
            value = val;
            depth = dep;
            type = t;
            return;

    }


}