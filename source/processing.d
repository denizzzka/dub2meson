module common;

import dub.dub;
import dub.internal.vibecompat.inet.path: NativePath;
import std.exception: enforce;
import app;

Dub createDub(in Cfg cfg)
{
    //TODO: add package_suppliers and options

    Dub dub;

    if(cfg.bare)
    {
        import std.file: getcwd;

        dub = new Dub(NativePath(getcwd()));
    }
    else
        dub = new Dub(cfg.rootPath);

    dub.rootPath = NativePath(cfg.rootPath);
    dub.dryRun = cfg.annotate;
    dub.defaultPlacementLocation = cfg.placementLocation;

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
    import std.file: mkdirRecurse;

    byte[string] processedPackages;

    foreach(currPkg; dub.project.getTopologicalPackageList)
    {
        const basePkgName = currPkg.basePackage.name;

        if(basePkgName !in processedPackages)
        {
            if(cfg.verbose)
            {
                import std.stdio;

                writefln(`Processing '%s' (%s)`,
                    basePkgName,
                    currPkg.basePackage.recipe.version_,
                );
            }

            createMesonFile(currPkg.basePackage, cfg);
            processedPackages[basePkgName] = 1;
        }
    }
}

import dub.package_: Package;
import meson.build_file;
import meson.primitives;
import std.stdio;

void createMesonFile(in Package pkg, in Cfg cfg)
{
    import dub.internal.vibecompat.core.file;

    immutable filename = `meson.build`;

    const NativePath mesonBuildFilePath = pkg.path ~ filename;

    if(mesonBuildFilePath.existsFile)
    {
        if(cfg.verbose)
            writeln("file ", mesonBuildFilePath, " exists, skipping");

        return;
    }

    const subprojects = NativePath(cfg.subprojectsPath);

    auto meson_build = new RootMesonBuildFile(subprojects~`packagefiles`~(pkg.name~`_changes`)~filename);

    // Adding project()
    {
        auto project = meson_build.rootSection.addFunc(
            `project`,
            [
                pkg.basePackage.name.quote,
                `['d']`,
            ],
            [
                `version`: pkg.basePackage.recipe.version_,
                `license`: pkg.basePackage.recipe.license,
                `meson_version`: `>=0.58.1`,
            ]
        );

        project.addArray(
            `default_options`.keyword,
            Bracket.SQUARE,
            [
                "FIXME".quote,
                "FIXME".quote,
            ]
        );
    }

    //Collect source files
    void collect(in string[][string] searchPaths, MesonBuildFile.CollectType ct, string typeName, string wildcard, bool isSourceFiles = false)
    {
        import dub_stuff.collect: collectFiles;

        auto collected = collectFiles(pkg.path, searchPaths, wildcard);

        foreach(suffix, files; pkg.recipe.buildSettings.sourceFiles)
            collected[suffix] ~= files;

        foreach(suffix, ref paths; collected)
        {
            const underscore = (suffix == "") ? "" : "_";

            if(ct == MesonBuildFile.CollectType.IncludeDirs)
            {
                // remove file part and '/' from paths
                foreach(ref p; paths)
                    p = NativePath(p).parentPath.toString[0 .. $-1];
            }

            import std.algorithm.sorting: sort;
            import std.algorithm.iteration: uniq;
            import std.array: array;

            paths = paths.sort.uniq.array;

            meson_build.addFilesToFilesArrays(ct, suffix~underscore~typeName, paths);
        }
    }

    {
        const bs = pkg.recipe.buildSettings;

        collect(bs.importPaths, MesonBuildFile.CollectType.IncludeDirs, `include`, `*.{d,di}`);
        collect(bs.sourcePaths, MesonBuildFile.CollectType.Files, `sources`, `*.d`, true);
        collect(bs.stringImportPaths, MesonBuildFile.CollectType.StringArray, `string_imports`, "*");
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
                    enforce(false, pkg.basePackage.name~`: unsupported target type: `~conf.buildSettings.targetType.to!string);
                    return;
            }

            processDependency(meson_build, conf.name, pkg, bo);

            // processExecOrLib can process both executable() and library():
            if(bo.buildExecutable)
                processExecOrLib(meson_build, conf.name, pkg, bo);

            if(bo.buildLibrary)
                processExecOrLib(meson_build, conf.name, pkg, bo);

            conf.buildSettings.targetType.writeln;
        }
    }

    meson_build.path.writeln;
    meson_build.writeln;
    //~ pkg.recipe.configurations.writeln;
    //~ pkg.recipe.buildSettings.writeln;
}

struct BuildOptions
{
    bool buildSomeBinary = true;
    bool buildExecutable;
    bool buildLibrary;
    bool forceDynamicLib;
    bool forceStaticLib;
}

void processDependency(RootMesonBuildFile meson_build, in string confName, in Package pkg, in BuildOptions bo)
{
    import std.algorithm.iteration: map;
    import std.array: array;

    const depsList = pkg.getDependencies(confName).byKey.array;

    foreach(ref e; depsList)
        meson_build.addDependency(e);

    auto dep = meson_build.rootSection.addFunc(
        confName~`_dep = declare_dependency`,
    );

    if(depsList.length != 0)
    {
        auto deps = dep.addArray(
            `dependencies`.keyword,
            Bracket.SQUARE,
            depsList.map!(a => a~`_dep`).array
        );
    }

    foreach(arrName, arrVals; meson_build.namedArrays)
    {
        dep.addArray(
            arrName.keyword,
            Bracket.SQUARE,
            arrVals
        );
    }
}

void processExecOrLib(RootMesonBuildFile meson_build, in string confName, in Package pkg, in BuildOptions bo)
{
    string name;
    string suffix;

    if(bo.buildExecutable)
    {
        name = `executable`;
        suffix = `_exe`;
    }
    else if(bo.buildLibrary)
    {
        name = `library`;
        suffix = `_lib`;
    }
    else
        assert(false);

    auto exeOrLib = meson_build.rootSection.addFunc(
        confName~suffix~` = `~name,
        [confName.quote],
    );

    auto deps = exeOrLib.addArray(
        `dependencies`.keyword,
        Bracket.SQUARE,
        [confName.quote]
    );
}
