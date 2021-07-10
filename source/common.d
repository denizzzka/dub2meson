module common;

import dub.dub;
import app;
import std.stdio;

void main_(string rootPath)
{
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

Dub getDub(in Cfg cfg)
{
	//TODO: add package_suppliers and options options
	auto dub = new Dub(cfg.rootPath);
	dub.dryRun = cfg.annotate;

	dub.loadPackage();

    return dub;
}

void fetchAllNonOptionalDependencies(Dub dub)
{
	if(!dub.project.hasAllDependencies)
		dub.upgrade(UpgradeOptions.none, dub.project.missingDependencies);
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
