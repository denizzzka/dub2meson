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

	auto meson_build = new MesonBuildFile(subprojects~`packagefiles`~(pkg.name~`_changes`)~filename);

	// Adding project()
	{
		auto project = meson_build.rootSection.addSection(`project`, Bracket.ROUND);
		project.addLine(pkg.basePackage.name.quote~`,`);
		project.addLine(`['d'],`);
		project.addKeyVal(`version`, pkg.basePackage.recipe.version_);
		project.addKeyVal(`license`, pkg.basePackage.recipe.license);
		project.addKeyVal(`meson_version`, `>=0.58.1`);
		project.addArray(
			`default_options`.keyword,
			Bracket.SQUARE,
			[
				"FIXME".quote,
				"FIXME".quote,
			]
		);
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

			//Collect files
			{
				import dub_stuff.collect: collectFiles;

				string[][string] remove_me;
				remove_me[""] = ["abc/def"];

				auto files = collectFiles(pkg, remove_me, "*.d");

				files.writeln;
			}

			// processExecOrLib can process both executable() and library():
			if(bo.buildExecutable)
				processExecOrLib(meson_build, conf, pkg, bo);

			if(bo.buildLibrary)
				processExecOrLib(meson_build, conf, pkg, bo);

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

void processSourceFiles(MesonBuildFile meson_build, in ConfigurationInfo conf, in Package pkg, in BuildOptions bo)
{
	import dub_stuff.collect;

	conf.writeln;

	//~ auto tree = collectFiles(srcPaths, "*.d");
}

import dub.recipe.packagerecipe: ConfigurationInfo;

void processExecOrLib(MesonBuildFile meson_build, in ConfigurationInfo conf, in Package pkg, in BuildOptions bo)
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

	//~ conf.writeln;

	import std.algorithm.iteration: map;
	import std.array: array;

	const depsList = pkg.getDependencies(conf.name).byKey.array;

	foreach(ref e; depsList)
		meson_build.addDependency(e);

	auto exeOrLib = meson_build.rootSection.addSection(conf.name~suffix~` = `~name, Bracket.ROUND);
	exeOrLib.addLine(conf.name.quote~`,`);

	auto deps = exeOrLib.addArray(
		`dependencies`.keyword,
		Bracket.SQUARE,
		depsList.map!(a => a~`_dep`).array
	);

	writeln("dependencies >>>>>>>>>>>> ", pkg.getDependencies(conf.name));
}
