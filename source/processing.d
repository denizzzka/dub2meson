module common;

import dub.dub;
import dub.project: PlacementLocation;
import dub.packagemanager: PackageManager;
import dub.internal.vibecompat.inet.path: NativePath;
import std.exception: enforce;
import meson.mangling: mangle;
import app;

Dub createDub(in Cfg cfg, PackageManager packageManager, PlacementLocation pl, in bool dryRun)
{
    //TODO: add package_suppliers and options

    import std.file: getcwd;
    import meson.wrap: defaultMesonPackageSuppliers;

    Dub dub;

    if(cfg.bare)
        dub = new Dub(NativePath(getcwd()));
    else
        dub = new Dub(cfg.rootPath);

    //~ dub.rootPath = NativePath(cfg.rootPath);
    dub.m_packageSuppliers = defaultMesonPackageSuppliers();

    if(packageManager !is null)
        dub.m_packageManager = packageManager;

    dub.dryRun = dryRun;
    dub.placementLocation = pl;

    dub.loadPackage();

    return dub;
}

void fetchAllNonOptionalDependencies(Dub dub)
{
    if(!dub.project.hasAllDependencies)
        dub.upgrade(UpgradeOptions.none, dub.project.missingDependencies);
}

void createMesonFiles(Dub dub, in Cfg cfg)
{
    bool isRootPackage = true;
    PackageRootMesonBuildFile[string] processedPackages;

    foreach(currPkg; dub.project.getTopologicalPackageList)
    {
        if(cfg.verbose)
        {
            import std.stdio;

            writefln(`Processing '%s' (%s)`,
                currPkg.name,
                currPkg.recipe.version_,
            );
        }

        const rootBasePackageName = dub.project.name;

        auto meson_build = processedPackages.require(
            currPkg.name,
            createMesonFile(currPkg, cfg, rootBasePackageName)
        );

        if(meson_build !is null)
            meson_build.processDubPackage(currPkg);

        processedPackages[currPkg.name] = meson_build;
        isRootPackage = false; // only first package is a root package
    }
}

import dub.package_: Package;
import meson.build_file;
import meson.primitives;
import std.stdio;

PackageRootMesonBuildFile createMesonFile(in Package pkg, in Cfg cfg, in string rootBasePackageName)
{
    import dub.internal.vibecompat.core.file: existsFile;

    if(!cfg.overrideMesonBuildFiles && pkg.path.existsFile)
    {
        if(cfg.verbose)
            writeln("file ", pkg.path, " exists, skipping");

        return null;
    }

    NativePath resultBasePackagePath;

    const isRootPackage = (pkg.basePackage.name == rootBasePackageName);

    if(isRootPackage)
        resultBasePackagePath = NativePath("./");
    else
    {
        const subprojects = NativePath(cfg.subprojectsPath);

        resultBasePackagePath = subprojects~`packagefiles`~(pkg.basePackage.path.head.name~`_changes`);
    }

    return createPackageMesonFile(pkg, resultBasePackagePath);
}

void processDubPackage(PackageRootMesonBuildFile meson_build, in Package pkg)
{
    immutable bool isSubPackage = pkg.parentPackage !is null;

    //Collect source files
    void collect(in string[][string] searchPaths, Group grp, string wildcard, bool isSourceFiles = false)
    {
        import dub_stuff.collect: collectFiles;

        auto collected = collectFiles(pkg.path, searchPaths, wildcard);

        foreach(suffix, files; pkg.recipe.buildSettings.sourceFiles)
            collected[suffix] ~= files;

        foreach(prefix, ref paths; collected)
        {
            if(grp == Group.include_directories)
            {
                // remove file part and '/' from paths
                foreach(ref p; paths)
                    p = NativePath(p).parentPath.toString[0 .. $-1];
            }

            import std.algorithm.sorting: sort;
            import std.algorithm.iteration: uniq;
            import std.array: array;

            paths = paths.sort.uniq.map!(a => a.quote).array;

            meson_build.addFilesToFilesArrays(grp, prefix.mangle(grp), paths);
        }
    }

    {
        const bs = pkg.recipe.buildSettings;

        collect(bs.importPaths, Group.include_directories, `*.{d,di}`);
        collect(bs.sourcePaths, Group.sources, `*.d`, true);
        collect(bs.stringImportPaths, Group.string_imports, "*");
    }

    // Loop over configurations
    {
        foreach(const conf; pkg.recipe.configurations)
        {
            import std.conv: to;
            import dub.recipe.packagerecipe;
            import dub.compilers.buildsettings: TargetType;

            BuildOptions bo;

            with(bo)
            with(TargetType)
            switch(conf.buildSettings.targetType)
            {
                case none:
                    buildSomeBinary = false;
                    continue; // Just ignore whole package

                case sourceLibrary:
                    buildSomeBinary = false;
                    break;

                case executable:
                    buildExecutable = true;
                    break;

                case library:
                    buildLibrary = true;
                    break;

                case autodetect:
                    buildExecutable = true;
                    buildLibrary = true;
                    break;

                case dynamicLibrary:
                    forceDynamicLib = true;
                    break;

                case staticLibrary:
                    forceStaticLib = true;
                    break;

                default:
                    enforce(false, pkg.name~`: unsupported target type: `~conf.buildSettings.targetType.to!string);
                    return;
            }

            processDependencies(meson_build, conf.name, pkg, bo);

            // processExecOrLib can process both executable() and library():
            if(bo.buildExecutable)
                processExecOrLib(meson_build, conf.name, pkg, bo);

            if(bo.buildLibrary)
                processExecOrLib(meson_build, conf.name, pkg, bo);
        }
    }

    //~ meson_build.path.writeln;
    //~ meson_build.writeln;
    //~ pkg.recipe.configurations.writeln;
    //~ pkg.recipe.buildSettings.writeln;
}

import std.algorithm.iteration: map;

struct BuildOptions
{
    bool buildSomeBinary = true;
    bool buildExecutable;
    bool buildLibrary;
    bool forceDynamicLib;
    bool forceStaticLib;
}

//FIXME: remove confName arg?
void processDependencies(PackageRootMesonBuildFile meson_build, in string confName, in Package pkg, in BuildOptions bo)
{
    import std.array: array;
    import dub.dependency: PackageDependency;

    const PackageDependency[] depsList = pkg.getAllDependencies();
    bool[string] processedDeps;

    foreach(ref e; depsList)
    {
        enforce(!(e.name in processedDeps), `Multiple deps with different specs isn't supported for now`);

        meson_build.addExternalDependency(e);

        processedDeps[e.name] = true;
    }

    auto dep = meson_build.addFunc(
        Group.dependencies,
        confName,
        confName.mangle(Group.dependencies)~` = declare_dependency`,
    );

    if(depsList.length != 0)
    {
        dep.addArray(
            `dependencies`.keyword,
            Bracket.SQUARE,
            depsList.map!(a => a.name.mangle(Group.dependencies)).array
        );
    }

    foreach(grp, vals; meson_build.rootSection.groups)
    {
        with(Group)
        if(
            grp == sources ||
            grp == include_directories ||
            grp == string_imports
        )
        {
            SortedLines lines;
            Statement arr = dep.addArray(grp.keyword, Bracket.SQUARE, [], lines, true);

            foreach(name; vals.byKey)
                lines.addLine(name);
        }
    }
}

void processExecOrLib(PackageRootMesonBuildFile meson_build, in string confName, in Package pkg, in BuildOptions bo)
{
    Group grp;
    string func;

    if(bo.buildExecutable)
    {
        grp = Group.executables;
        func = `executable`;
    }
    else if(bo.buildLibrary)
    {
        grp = Group.libraries;
        func = `library`;
    }
    else
        assert(false);

    auto exeOrLib = meson_build.addFunc(
        null,
        confName,
        confName.mangle(grp)~` = `~func,
        [confName.quote],
    );

    auto deps = exeOrLib.addArray(
        `dependencies`.keyword,
        Bracket.SQUARE,
        [confName.mangle(Group.dependencies)]
    );
}
