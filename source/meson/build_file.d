module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import meson.primitives;
import meson.mangling: mangle, substForbiddenSymbols;
import app: cfg;

class MesonBuildFile
{
    static immutable filename = `meson.build`;
    const NativePath fileDir;
    Section rootSection;

    private this(NativePath _fileDir)
    {
        assert(_fileDir.endsWithSlash);

        rootSection = new Section();
        fileDir = _fileDir;
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

    package void rewriteFile(NativePath destDir)
    {
        import meson.primitives: Lines;

        Lines content;
        rootSection.toLines(content, 0);

        destDir ~= destDir ~ fileDir;
        const destFile = destDir ~ MesonBuildFile.filename;

        static import std.stdio;
        static import std.file;

        if(cfg.verbose)
            std.stdio.writeln(`Write file `, destFile.toString.quote);

        if(!cfg.annotate)
        {
            import vibe.core.file;
            import std.typecons: Yes;

            createDirectory(destDir, Yes.recursive);
            std.file.write(destFile.toString, content.data);
        }
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

/// Represents root meson.build file for DUB package or subpackage
class RootMesonBuildFile : MesonBuildFile
{
    import dub.package_: Package;

    const Package pkg;

    this(in Package pkg, in NativePath fileDir, in string _rootBasePackageName /*FIXME: remove*/)
    {
        this.pkg = pkg;

        super(fileDir);

        allMesonBuildFiles[fileDir] = this;
    }

    //TODO: remove
    string rootBasePackageName() const
    {
        return pkg.name;
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
            [name.substForbiddenSymbols.quote],
            version_ ? [`version`: version_] : null,
        );

        if(default_options !is null)
            s.addArray(
                `default_options`.keyword,
                Bracket.SQUARE,
                default_options
            );
    }

    import dub.dependency: PackageDependency;

    void addExternalDependency(in PackageDependency pkgDep)
    {
        import std.format: format;
        import meson.wrap: createWrapFile;
        import dub.recipe.packagerecipe: getBasePackageName;

        // If something depends from root project it isn't necessary to add external dependency ("subproject" directive)
        if(pkgDep.name /*FIXME: fetch base name*/ == rootBasePackageName)
            return;

        //TODO: subprojects support
        const name = pkgDep.name.getBasePackageName;

        // Already defined?
        if(getSectionOrNull(Group.external_dependencies, name) !is null)
            return;

        createWrapFile(name);

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
        sec.add = new UnsortedLines([oneline], false);

        add(grp, name, sec);
    }

    static void rewriteFiles()
    {
        const destDir = NativePath(cfg.rootPath);

        foreach(f; allMesonBuildFiles.byValue)
            f.rewriteFile(destDir);
    }

    override string toString() const
    {
        Lines ret;

        return rootSection.toLines(ret, 0).data;
    }
}

/// Represents root meson.build file for DUB package
class PackageRootMesonBuildFile : RootMesonBuildFile
{
    this(in Package pkg, in NativePath fileDir)
    {
        super(pkg, fileDir, null);

        addProject();
    }

    private void addProject()
    {
        auto project = addFunc(
            null,
            null,
            `project`,
            [
                pkg.name.quote,
                `['d']`,
            ],
            [
                `version`: pkg.recipe.version_,
                `license`: pkg.recipe.license,
                `meson_version`: `>=0.58.1`,
            ]
        );

        //~ project.addArray(
            //~ `default_options`.keyword,
            //~ Bracket.SQUARE,
            //~ [
                //~ "FIXME".quote,
                //~ "FIXME".quote,
            //~ ]
        //~ );
    }
}
