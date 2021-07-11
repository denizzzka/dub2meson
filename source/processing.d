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

void createMesonFile(in Package pkg, in Cfg cfg)
{
	import std.stdio;
	import dub.internal.vibecompat.core.file;

	immutable filename = `meson.build`;

	const NativePath mesonBuildFilePath = pkg.path ~ filename;

	if(mesonBuildFilePath.existsFile)
	{
		if(cfg.verbose)
			writeln("file ", mesonBuildFilePath, " exists, skipping");

		return;
	}

	import meson.build_file;

	const subprojects = NativePath(cfg.subprojectsPath);

	auto meson_build = new MesonBuildFile(subprojects~`packagefiles`~(pkg.name~`_changes`)~filename);

	// Adding project()
	{
		auto project = meson_build.rootSection.addSection(`void project`, Bracket.ROUND);
		project.addLine(pkg.basePackage.name.quote~`,`);
		project.addLine(`license`.keyword~pkg.basePackage.recipe.license.quote~`,`);

		auto defOptions =  project.addArray(
			`default_options`.keyword,
			Bracket.SQUARE,
			[
				"default_library=static".quote,
				"default_library=static".quote,
			]
		);
	}

	meson_build.path.writeln;
	meson_build.writeln;

	//~ pkg.recipe.writeln;
}
