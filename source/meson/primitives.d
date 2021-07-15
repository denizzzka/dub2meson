module meson.primitives;

import dub.internal.vibecompat.inet.path: NativePath;
import std.array: Appender;

abstract class PayloadPiece
{
    ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const;
}

class UnsortedLines : PayloadPiece
{
    protected string[] lines;

    package this(string[] l = null)
    {
        lines = l;
    }

    void addLine(string l)
    {
        lines ~= l;
    }

    void addLines(string[] l)
    {
        lines ~= l;
    }

    override ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const
    {
        foreach(e; lines)
        {
            ret.addOffset(offsetCnt);
            ret ~= e ~ ",\n";
        }

        return ret;
    }
}

class SortedLines : UnsortedLines
{
    package this(string[] l = null)
    {
        lines = l;
    }

    override ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const
    {
        import std.algorithm.sorting: sort;

        string[] copy = lines.dup;

        foreach(e; copy.sort)
        {
            ret.addOffset(offsetCnt);
            ret ~= e ~ ",\n";
        }

        return ret;
    }
}

class Section : PayloadPiece
{
    private PayloadPiece[] payload;

    PayloadPiece add(PayloadPiece pp)
    {
        payload ~= pp;

        return pp;
    }

    MesonFunction addFunc(string id, string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        auto ret = new MesonFunction(id, firstLine, unnamed, keyVal);

        add(ret);

        return ret;
    }

    override ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const
    {
        foreach(piece; payload)
            piece.toLines(ret, offsetCnt);

        return ret;
    }
}

class OffsetSection : Section
{
    override ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const
    {
        return super.toLines(ret, offsetCnt + 1);
    }
}

class Statement : OffsetSection
{
    string firstLine;
    Bracket bracket;

    private this(string _firstLine, Bracket br)
    {
        firstLine= _firstLine;
        bracket = br;
    }

    override ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const
    {
        char firstBr =  (bracket == Bracket.SQUARE) ? '[' : '(';
        char latestBr = (bracket == Bracket.SQUARE) ? ']' : ')';

        ret.addOffset(offsetCnt);
        ret ~= firstLine ~ firstBr ~ '\n';

        super.toLines(ret, offsetCnt);

        ret.addOffset(offsetCnt);
        ret ~= latestBr ~ "\n";

        return ret;
    }
}

class MesonFunction : Statement
{
    const string uniqId;

    private this(string _uniqId, string firstLine, string[] unnamed, string[string] keyVal)
    {
        uniqId = _uniqId;

        super(firstLine, Bracket.ROUND);

        auto lines = new UnsortedLines(unnamed);
        super.add(lines);

        auto sorted = new SortedLines();
        super.add(sorted);

        foreach(k, v; keyVal)
            sorted.addLine(k.keyword~v.quote);
    }
}

SortedLines addArray(Section sec, string firstLine, Bracket br, string[] arr)
{
    import std.algorithm.sorting: sort;

    auto stmnt = new Statement(firstLine, br);
    auto lines = new SortedLines(arr);
    stmnt.add = lines;
    sec.add = stmnt;

    return lines;
}

void addArray(Section sec, string firstLine, Bracket br, UnsortedLines lines)
{
    auto stmnt = new Statement(firstLine, br);
    sec.add = stmnt;

    stmnt.add = lines;
}

import std.exception: enforce;
import std.format: format;
import std.algorithm.searching: canFind;

string quote(string s)
{
    enforce(!canFind(s, '\''), `Forbidden symbol`);

    return format(`'%s'`, s);
}

string keyword(string s)
{
    enforce(!canFind(s, '\''), `Forbidden symbol`);

    return format(`%s: `, s);
}

enum Bracket : char
{
    SQUARE, // [
    ROUND,  // (
}

immutable offsetSpaces = `    `;

alias Lines = Appender!string;

private static void addOffset(ref Lines lines, size_t offsetCnt)
{
    foreach(_; 0 .. offsetCnt)
        lines ~= offsetSpaces;
}
