module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import meson.primitives;

class MesonBuildFile
{
    const NativePath path;
    Section rootSection;

    private this(NativePath filePath)
    {
        rootSection = new Section();
        path = filePath;
    }

    private MesonBuildFile[] children;

    MesonBuildFile createOrGetMesonBuildFile(NativePath filePath)
    {
        auto ret = createOrGetMesonBuildFile(filePath);
        children ~= ret;

        return ret;
    }

    /*private*/ SortedLines[string] namedArrays;

    enum CollectType
    {
        Files,
        IncludeDirs,
        StringArray,
    }

    void addFilesToFilesArrays(CollectType ct, string arrName, string[] elems)
    {
        Group grp;
        string arrDirective;

        with(Group)
        with(CollectType)
        final switch(ct)
        {
            case Files:
                grp = sources;
                arrDirective = ` = files`;
                break;

            case IncludeDirs:
                grp = include_directories;
                arrDirective = ` = include_directories`;
                break;

            case StringArray:
                grp = string_imports;
                arrDirective = ` = `;
                break;
        }

        const brckType = (ct != CollectType.StringArray) ? Bracket.ROUND : Bracket.SQUARE;

        auto arrSection = rootSection.addArray(arrName ~ arrDirective, brckType, [], grp);

        arrSection.addLines(elems);
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

    private Section[string] subprojects;

    private void addSubproject(string name, string[] default_options, string version_)
    {
        if(name in subprojects)
            return;

        auto s = rootSection.addFunc(
            Group.subprojects,
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

    private bool[string] dependencies; //TODO: join into namedArrays

    void addDependency(string name)
    {
        import std.format: format;

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
