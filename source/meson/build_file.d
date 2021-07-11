module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import std.array: Appender;
import mir.algebraic: Variant;

alias PayloadPiece = Variant!(Section*, string);
alias SectionPayload = Appender!(PayloadPiece[]);

struct Section
{
    SectionPayload payload;
    alias payload this;

    void addLine(string line)
    {
        payload ~= line.PayloadPiece;
    }

    Section* addSection()
    {
        auto s = new Section;

        payload ~= s.PayloadPiece;

        return s;
    }

    Section* addSection(string firstLine, Bracket br)
    {
        char firstBr =  (br == Bracket.SQUARE) ? '[' : '(';
        char latestBr = (br == Bracket.SQUARE) ? ']' : ')';

        payload ~= (firstLine ~ firstBr).PayloadPiece;

        auto sec = addSection();

        payload ~= (`` ~ latestBr).PayloadPiece;

        return sec;
    }

    Section* addArray(string firstLine, Bracket br, string[] arr)
    {
        auto sec = addSection(firstLine, br);

        foreach(e; arr)
            sec.payload ~= (e ~ ',').PayloadPiece;

        return sec;
    }

    Lines toLines() const
    {
        Lines ret;

        return toLines(ret, 0);
    }

    Lines toLines(ref Lines ret, in size_t offsetCnt) const
    {
        foreach(piece; payload)
        {
            if(piece._is!string)
            {
                ret.addOffset(offsetCnt);
                ret ~= piece.get!string;
                ret ~= '\n';
            }
            else
            {
                const s = piece.get!(Section*);

                s.toLines(ret, offsetCnt + 1);
            }
        }

        return ret;
    }
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

class MesonBuildFile
{
    private NativePath path;
    Section rootSection;

    this(NativePath filePath)
    {
        path = filePath;
    }

    override string toString() const
    {
        return rootSection.toLines.data;
    }
}
