module common;

import dub.dub;
import dub.internal.vibecompat.inet.path: NativePath;
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

	const subprojects = NativePath(cfg.subprojectsPath);

    foreach(currPkg; dub.project.getTopologicalPackageList)
    {
		if(cfg.verbose)
		{
			import std.stdio;

			writefln(`Processing '%s' (%s)`,
				currPkg.recipe.name,
				currPkg.recipe.version_,
			);
		}

        createMesonFile(currPkg, subprojects);
    }
}

import dub.package_: Package;

void createMesonFile(in Package pkg, in NativePath subprojects)
{
	//проверить что нету файла мезон.билд
}

void main_(string rootPath)
{
    import std.stdio;

    string rootPackagePath = ".";

    //TODO: add package_suppliers and options options
    auto dub = new Dub(rootPath);
    //~ dub.dryRun = true;

    dub.rootPath.writeln;

    dub.loadPackage();

    dub.project.name.writeln;
    dub.project.configurations.writeln;

    dub.fetchAllNonOptionalDependencies;

    foreach(currPkg; dub.project.getTopologicalPackageList)
    {
        currPkg.recipe.name.write;
        " ".write;
        currPkg.recipe.version_.writeln;
    }
}

//~ import dub.package_: Package;

//~ import dub.dependency;
//~ import dub.dependencyresolver;

    //~ import dub.recipe.packagerecipe;

    //~ import dub.platform: BuildPlatform;

    //~ auto platform = BuildPlatform.any;

    //~ const defConf = dub.project.getDefaultConfiguration(platform, true);
    //~ defConf.writeln;

    //~ dub.project.getPackageConfigs(platform, defConf, true).writeln;
