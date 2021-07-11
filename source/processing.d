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

			createMesonFile(currPkg.basePackage, subprojects, cfg);
			processedPackages[basePkgName] = 1;
		}
    }
}

import dub.package_: Package;

void createMesonFile(in Package pkg, in NativePath subprojects, in Cfg cfg)
{
	import std.stdio;

	//~ pkg.basePackage.name.write;
	//~ pkg.basePackage.path.writeln;

	import dub.internal.vibecompat.core.file;

	const NativePath mesonFile = pkg.basePackage.path ~ `meson.build`;

	if(mesonFile.existsFile)
	{
		if(cfg.verbose)
			writeln("file ", mesonFile, " exists, skipping");

		return;
	}

	import meson.build_file;

	auto meson_build = new MesonBuildFile();

	meson_build.rootSection.addLine("void project(");
	auto proj = meson_build.rootSection.addSection();
	proj.addLine(pkg.basePackage.name.quote~`,`);
	proj.addLine(`license: `~pkg.basePackage.recipe.license.quote~`,`);
	proj.addLine(`default_options: [`);
	auto defOptions = proj.addSection();
	defOptions.addLine("'default_library=static'".quote);
	defOptions.addLine("'b_staticpic=false'");
	proj.addLine(`]`);
	meson_build.rootSection.addLine(")");
	//~ meson_build.addPiece(&Section());

	//~ meson_build.addLine("abc", 1);
	meson_build.writeln;

	//~ pkg.recipe.writeln;
}
