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

enum Group : string
{
    sources = `sources`,
    include_directories = `include_directories`,
    string_imports = `__string_imports__`,
    dependencies = `dependencies`,
    subprojects = `__subprojects__`,
}

struct SectionID
{
    Group group;
    string name;
}

alias SectionsByID = Section[string];

class Section : PayloadPiece
{
    /*private*/ PayloadPiece[] payload;

    PayloadPiece add(PayloadPiece pp)
    {
        payload ~= pp;

        return pp;
    }

    /*private*/ SectionsByID[Group] groups;

    package void addToGroup(Group group, string name, Section sec)
    {
        groups[name][group] = sec;
    }

    package ref Section add(Group group, string name, ref return Section sec)
    {
        add(sec);

        return sec;
    }

    package MesonFunction addFunc(string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        auto ret = new MesonFunction(firstLine, unnamed, keyVal);

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
    private this(string firstLine, string[] unnamed, string[string] keyVal)
    {
        super(firstLine, Bracket.ROUND);

        auto lines = new UnsortedLines(unnamed);
        super.add(lines);

        auto sorted = new SortedLines();
        super.add(sorted);

        foreach(k, v; keyVal)
            sorted.addLine(k.keyword~v.quote);
    }
}

//TODO: simplify addArray stuff
Statement addArray(Section sec, string firstLine, Bracket br, ref SortedLines lines)
{
    auto stmnt = new Statement(firstLine, br);
    stmnt.add = lines;
    sec.add = stmnt;

    return stmnt;
}

Statement addArray(Section sec, string firstLine, Bracket br, string[] arr, out SortedLines lines)
{
    lines = new SortedLines(arr);

    return sec.addArray(firstLine, br, lines);
}

SortedLines addArray(Section sec, string firstLine, Bracket br, string[] arr)
{
    SortedLines lines;

    sec.addArray(firstLine, br, arr, lines);

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
