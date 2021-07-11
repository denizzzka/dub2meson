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

    void addPiece(T)(T piece)
    {
        rootSection.payload ~= piece.PayloadPiece;
    }

    override string toString() const
    {
        return rootSection.toLines.data;
    }
}
