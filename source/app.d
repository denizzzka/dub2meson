module app;

import std.stdio;
import std.getopt;

struct Cfg
{
	import dub.project: PlacementLocation;

	string rootPath = ".";
	string subprojectsPath = "subprojects";
	bool annotate;
	bool bare;
	bool fetch;
	PlacementLocation placementLocation = PlacementLocation.user;
	bool verbose;
}

void main(string[] args)
{
	Cfg cfg;

	with(cfg)
	{
		//TODO: add --registry=VALUE and --skip-registry=VALUE
		auto helpInformation = getopt(
			args,
			`root`, `Path to operate in instead of the current working dir`, &rootPath,
			`subprojects`, `Path to subprojects dir instead of Meson default`, &subprojectsPath,
			`annotate`, `Do not perform any action, just print what would be done`, &annotate,
			"bare", `Read only packages contained in the current directory`, &bare,
			"fetch-only", `Only fetch all non-optional dependencies`, &fetch,
			"cache", `Puts any fetched packages in the specified location [local|system|user]`, &placementLocation,
			`verbose`, `Print diagnostic output`, &verbose,
		);

		if (helpInformation.helpWanted)
		{
			defaultGetoptPrinter("Usage:",
				helpInformation.options);

			return;
		}
	}

	import common;

	auto dub = createDub(cfg);
	dub.fetchAllNonOptionalDependencies;

	if(!cfg.fetch)
		dub.createMesonFiles(cfg);
}
