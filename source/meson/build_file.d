module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import meson.primitives;
import meson.mangling: mangle;

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

        SortedLines lines;
        Section arrSection = rootSection.addArray(arrName ~ arrDirective, brckType, [], lines, false);
        rootSection.addToGroup(grp, arrName, arrSection);

        lines.addLines(elems);
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
    const string dubBasePackageName;

    this(NativePath filePath, string basePackageName)
    {
        super(filePath);

        dubBasePackageName = basePackageName;

        allMesonBuildFiles[filePath] = this;
    }

    ref Section add(Group group, string name, ref return Section sec)
    {
        rootSection.add(sec);
        rootSection.addToGroup(group, name, sec);

        return sec;
    }

    MesonFunction addFunc(Group group, string name, string firstLine, string[] unnamed = null, string[string] keyVal = null)
    {
        auto ret = rootSection.addFunc(firstLine, unnamed, keyVal);

        rootSection.addToGroup(group, name, ret);

        return ret;
    }

    Section getSectionOrNull(Group group, string name)
    {
        auto g = group in rootSection.groups;

        if(g is null)
            return null;

        auto s = name in *g;

        if(s is null)
            return null;
        else
            return *s;
    }

    private void addSubproject(string name, string[] default_options, string version_)
    {
        immutable grp = Group.subprojects;

        if(getSectionOrNull(grp, name) !is null)
            return;

        auto s = addFunc(
            grp,
            name,
            name.mangle(grp)~` = subproject`,
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

    void addExternalDependency(string baseName)
    {
        import std.format: format;

        const name = baseName;

        // If depends from this Meson project it isn't need to add "subproject" directive
        if(baseName == dubBasePackageName)
            return;

        // Already defined?
        if(getSectionOrNull(Group.external_dependencies, name) !is null)
            return;

        addSubproject(name, null, null);

        addOneLineDirective(
            Group.external_dependencies,
            name,
            `%s = %s.get_variable('%s')`.format(
                name.mangle(Group.dependencies),
                name.mangle(Group.subprojects),
                name.mangle(Group.dependencies),
            )
        );
    }

    private void addOneLineDirective(Group grp, string name, string oneline)
    {
        auto sec = new Section;
        sec.add = new UnsortedLines([oneline]);

        add(grp, name, sec);
    }

    override string toString() const
    {
        Lines ret;

        return rootSection.toLines(ret, 0).data;
    }
}
