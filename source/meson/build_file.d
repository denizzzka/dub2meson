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

    void addKeyVal(string key, string val)
    {
        addLine(key.keyword~val.quote~`,`);
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

        payload ~= (`` ~ latestBr ~ ',').PayloadPiece;

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
    const NativePath path;

    this(NativePath filePath)
    {
        path = filePath;
    }
}

class RootMesonBuildFile : MesonBuildFile
{
    Section rootSection;

    this(NativePath filePath)
    {
        super(filePath);
    }

    private Section*[string] subprojects;

    private void addSubproject(string name, string[] default_options, string version_)
    {
        if(name in subprojects)
            return;

        auto s = rootSection.addSection(name~`_sub = subproject`, Bracket.ROUND);
        s.addLine(name.quote~`,`);

        if(version_ !is null)
            s.addKeyVal(`version`, version_);

        if(default_options !is null)
            s.addArray(
                `default_options`.keyword,
                Bracket.SQUARE,
                default_options
            );

        subprojects[name] = s;
    }

    private bool[string] dependencies;

    void addDependency(string name)
    {
        if(name in dependencies)
            return;

        addSubproject(name, null, null);
        rootSection.addLine(`%s_dep = %s_sub.get_variable('%s_dep')`.format(name, name, name));
        dependencies[name] = true;
    }

    override string toString() const
    {
        return rootSection.toLines.data;
    }
}
