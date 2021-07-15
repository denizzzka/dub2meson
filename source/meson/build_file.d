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

    void addFilesToFilesArrays(Group grp, string arrName, string[] elems)
    {
        string arrDirective;

        with(Group)
        switch(grp)
        {
            case sources:
                arrDirective = ` = files`;
                break;

            case include_directories:
                arrDirective = ` = include_directories`;
                break;

            case string_imports:
                arrDirective = ` = `;
                break;

            default:
                assert(false, "Unsupported group: "~grp);
        }

        const brckType = (grp != Group.string_imports) ? Bracket.ROUND : Bracket.SQUARE;

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

enum Group : string
{
    sources = `sources`,
    include_directories = `include_directories`,
    string_imports = `__string_imports__`,
    dependencies = `dependencies`,
    subprojects = `__subprojects__`,
}

class RootMesonBuildFile : MesonBuildFile
{
    this(NativePath filePath)
    {
        super(filePath);

        allMesonBuildFiles[filePath] = this;
    }

    ref Section add(string group, ref return Section sec)
    {
        return rootSection.add(group, sec);
    }

    MesonFunction addFunc(string group, string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        return rootSection.addFunc(group, firstLine, unnamed, keyVal);
    }

    bool isGroupAvailable(string name) const
    {
        return (name in rootSection.groups) !is null;
    }

    private void addSubproject(string name, string[] default_options, string version_)
    {
        if(isGroupAvailable(name))
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
    }

    private bool[string] dependencies; //TODO: join into namedArrays

    void addExternalDependency(string name)
    {
        import std.format: format;

        if(isGroupAvailable(name))
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
