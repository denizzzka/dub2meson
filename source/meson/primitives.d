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

alias Group_ = string;

class Section : PayloadPiece
{
    /*private*/ PayloadPiece[] payload;

    PayloadPiece add(PayloadPiece pp)
    {
        payload ~= pp;

        return pp;
    }

    /*private*/ Section[string] groups;

    package ref Section add(Group_ group, ref return Section sec)
    {
        add(sec);

        if(group !is null)
            groups.require(group, sec);

        import std.stdio;
        writeln(">>>>>> Section ", sec, " added, grp==", group);

        return sec;
    }

    package MesonFunction addFunc(Group_ group, string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        auto ret = new MesonFunction(group, firstLine, unnamed, keyVal);

        add(ret);

        if(group !is null)
            groups.require(group, ret);

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
    const string groupId;
    string firstLine;
    Bracket bracket;

    private this(string _groupId, string _firstLine, Bracket br)
    {
        groupId = _groupId;
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
    private this(string groupId, string firstLine, string[] unnamed, string[string] keyVal)
    {
        super(groupId, firstLine, Bracket.ROUND);

        auto lines = new UnsortedLines(unnamed);
        super.add(lines);

        auto sorted = new SortedLines();
        super.add(sorted);

        foreach(k, v; keyVal)
            sorted.addLine(k.keyword~v.quote);
    }
}

Statement addArray(Section sec, string firstLine, Bracket br, PayloadPiece lines, string groupId = null)
{
    auto stmnt = new Statement(groupId, firstLine, br);
    sec.add = stmnt;

    stmnt.add = lines;

    return stmnt;
}

SortedLines addArray(Section sec, string firstLine, Bracket br, string[] arr, string groupId = null)
{
    auto lines = new SortedLines(arr);
    sec.addArray(firstLine, br, lines, groupId);

    return lines;
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
