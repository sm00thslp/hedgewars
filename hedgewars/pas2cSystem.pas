system;

type 
    LongInt = integer;
    LongWord = integer;
    Cardinal = integer;
    PtrInt = integer;
    Word = integer;
    Integer = integer;
    Byte = integer;
    SmallInt = integer;
    ShortInt = integer;

    pointer = pointer;
    PChar = pointer;

    double = float;
    real = float;
    float = float;

    boolean = boolean;
    LongBool = boolean;

    string = string;
    shortstring = string;
    ansistring = string;

    char = char;
    
    PByte = ^Byte;
    PLongInt = ^LongInt;
    PLongWord = ^LongWord;
    PInteger = ^Integer;
var 
    false, true: boolean;
    write, writeLn, read, readLn, inc, dec: procedure;
    StrLen, ord, Succ, Pred : function : integer;
    Low, High : function : integer;
    Now : function : integer;
    SysUtils.StrPas, FormatDateTime : function : shortstring;
    exit : procedure;