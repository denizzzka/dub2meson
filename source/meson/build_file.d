module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import std.array: Appender;

abstract class PayloadPiece_
{
    ref Lines toLines(ref return Lines ret, in size_t offsetCnt) const;
}

class UnsortedLines : PayloadPiece_
{
    protected string[] lines;

    this(string[] l = null)
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
    this(string[] l = null)
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

class Section_ : PayloadPiece_
{
    private PayloadPiece_[] payload;

    PayloadPiece_ add(PayloadPiece_ pp)
    {
        payload ~= pp;

        return pp;
    }

    Func addFunc(string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        auto ret = new Func(firstLine, unnamed, keyVal);

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

class OffsetSection : Section_
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

class Func : Statement
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

SortedLines addArray(Section_ sec, string firstLine, Bracket br, string[] arr)
{
    import std.algorithm.sorting: sort;

    auto stmnt = new Statement(firstLine, br);
    auto lines = new SortedLines(arr);
    stmnt.add = lines;
    sec.add = stmnt;

    return lines;
}

//~ struct Section
//~ {
    //~ SectionPayload payload;
    //~ alias payload this;

    //~ void addLine(string line)
    //~ {
        //~ payload ~= line.PayloadPiece;
    //~ }

    //~ void addKeyVal(string key, string val)
    //~ {
        //~ addLine(key.keyword~val.quote~`,`);
    //~ }

    //~ Section* addSection()
    //~ {
        //~ auto s = new Section;

        //~ payload ~= s.PayloadPiece;

        //~ return s;
    //~ }

    //~ Section* addSection(string firstLine, Bracket br)
    //~ {
        //~ char firstBr =  (br == Bracket.SQUARE) ? '[' : '(';
        //~ char latestBr = (br == Bracket.SQUARE) ? ']' : ')';

        //~ payload ~= (firstLine ~ firstBr).PayloadPiece;

        //~ auto sec = addSection();

        //~ payload ~= (`` ~ latestBr ~ ',').PayloadPiece;

        //~ return sec;
    //~ }

    //~ Section* addArray(string firstLine, Bracket br, string[] arr)
    //~ {
        //~ import std.algorithm.sorting: sort;

        //~ auto sec = addSection(firstLine, br);

        //~ foreach(e; arr.sort)
            //~ sec.payload ~= (e ~ ',').PayloadPiece;

        //~ return sec;
    //~ }

    //~ Lines toLines() const
    //~ {
        //~ Lines ret;

        //~ return toLines(ret, 0);
    //~ }

    //~ Lines toLines(ref Lines ret, in size_t offsetCnt) const
    //~ {
        //~ foreach(piece; payload)
        //~ {
            //~ if(piece._is!string)
            //~ {
                //~ ret.addOffset(offsetCnt);
                //~ ret ~= piece.get!string;
                //~ ret ~= '\n';
            //~ }
            //~ else
            //~ {
                //~ const s = piece.get!(Section*);

                //~ s.toLines(ret, offsetCnt + 1);
            //~ }
        //~ }

        //~ return ret;
    //~ }
//~ }

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
    Section_ rootSection;

    private this(NativePath filePath)
    {
        rootSection = new Section_();
        path = filePath;
    }

    private MesonBuildFile[] children;

    MesonBuildFile createOrGetMesonBuildFile(NativePath filePath)
    {
        auto ret = createOrGetMesonBuildFile(filePath);
        children ~= ret;

        return ret;
    }

    private SortedLines[string] namedArrays;

    enum CollectType
    {
        Files,
        IncludeDirs,
        StringArray,
    }

    void addFilesToFilesArrays(CollectType ct, string arrName, string[] elems)
    {
        import std.algorithm.iteration: map;
        import std.algorithm.sorting: sort;
        import std.array: array;

        string arrDirective;

        with(CollectType)
        final switch(ct)
        {
            case Files:
                arrDirective = ` = files`;
                break;

            case IncludeDirs:
                arrDirective = ` = include_directories`;
                break;

            case StringArray:
                arrDirective = ` = `;
                break;
        }

        const brckType = (ct != CollectType.StringArray) ? Bracket.ROUND : Bracket.SQUARE;

        auto arrSection = namedArrays.require(
            arrName,
            rootSection.addArray(arrName ~ arrDirective, brckType, [])
        );

        auto arr = elems.map!(a => a.quote).array.sort.array;

        arrSection.addLines(arr);
    }
}

private static MesonBuildFile[NativePath] allMesonBuildFiles;

private MesonBuildFile createOrGetMesonBuildFile(in NativePath filePath)
{
    MesonBuildFile* bf = filePath in allMesonBuildFiles;

    if(bf !is null)
        return *bf;
    else
    {
        MesonBuildFile n = new MesonBuildFile(filePath);
        allMesonBuildFiles[filePath] = n;
        return n;
    }
}

class RootMesonBuildFile : MesonBuildFile
{
    this(NativePath filePath)
    {
        super(filePath);

        allMesonBuildFiles[filePath] = this;
    }

    private Section_[string] subprojects;

    private void addSubproject(string name, string[] default_options, string version_)
    {
        if(name in subprojects)
            return;

        auto s = rootSection.addFunc(
            name~`_sub = subproject`,
            [name.quote],
            version_ ? [`version`: version_] : null,
        );

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
        rootSection.add = new UnsortedLines([`%s_dep = %s_sub.get_variable('%s_dep')`.format(name, name, name)]);
        dependencies[name] = true;
    }

    override string toString() const
    {
        Lines ret;

        return rootSection.toLines(ret, 0).data;
    }
}
