module meson.build_file;

import dub.internal.vibecompat.inet.path: NativePath;
import meson.primitives;
import meson.mangling: mangle, substForbiddenSymbols;
import app: cfg;
import dub.package_: Package;

class MesonBuildFile
{
    static immutable filename = `meson.build`;
    const NativePath fileDir;
    Section rootSection;
    private MesonBuildFile[] children;
    private static MesonBuildFile[NativePath] allMesonBuildFiles;

    private this(NativePath _fileDir)
    {
        assert(_fileDir.endsWithSlash);

        rootSection = new Section();
        fileDir = _fileDir;
    }

    MesonBuildFile createOrGetMesonBuildFile(NativePath filePath)
    {
        MesonBuildFile* bf = filePath in allMesonBuildFiles;

        if(bf !is null)
            return *bf;

        MesonBuildFile ret = new MesonBuildFile(filePath);
        children ~= ret;

        allMesonBuildFiles[filePath] = ret;
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

        import meson.fs: rewriteFile;

        destFile.rewriteFile(content.data);
    }
}

/// Represents root meson.build file for DUB package or subpackage
class PackageRootMesonBuildFile : MesonBuildFile
{
    const Package pkg;

    package this(in Package pkg, in NativePath fileDir)
    {
        import dub.internal.vibecompat.core.file: relativeTo;

        this.pkg = pkg;

        //Take into consideration subpackage dir:
        const relDir = fileDir~pkg.path.relativeTo(pkg.basePackage.path);
        super(relDir);

        allMesonBuildFiles[relDir] = this;
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

private PackageRootMesonBuildFile[string] basePackageBuildFiles;

/// Represents root meson.build file for DUB package
class BasePackageRootMesonBuildFile : PackageRootMesonBuildFile
{
    package this(in Package pkg, in NativePath fileDir)
    {
        import dub.recipe.packagerecipe: getBasePackageName;

        assert(pkg.name == pkg.name.getBasePackageName, `Only base packages can be represented by root meson.build file`);

        super(pkg, fileDir);

        addProject();

        basePackageBuildFiles[pkg.name] = this;
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

    PackageRootMesonBuildFile createSubpackage(in Package pkg, NativePath filePath)
    {
        auto created = new PackageRootMesonBuildFile(pkg, filePath);

        children ~= created;

        return created;
    }
}

PackageRootMesonBuildFile createPackageMesonFile(in Package pkg, in NativePath resultBasePackagePath)
{
    if(pkg.name == pkg.basePackage.name)
        return new BasePackageRootMesonBuildFile(pkg, resultBasePackagePath);

    auto basePkg = cast(BasePackageRootMesonBuildFile) basePackageBuildFiles.require(
        pkg.basePackage.name,
        new BasePackageRootMesonBuildFile(pkg.basePackage, resultBasePackagePath)
    );

    return basePkg.createSubpackage(pkg, resultBasePackagePath);
}
