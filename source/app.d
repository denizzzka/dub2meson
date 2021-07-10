import std.stdio;
import dub.dub;

void main(string[] args)
{
	string rootPackagePath = args[1];

	//TODO: add package_suppliers and options options
	auto dub = new Dub(rootPackagePath);
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

void fetchAllNonOptionalDependencies(Dub dub)
{
	if(!dub.project.hasAllDependencies)
	{
		dub.upgrade(UpgradeOptions.none, dub.project.missingDependencies);
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
