module app;

import std.stdio;
import std.getopt;

struct Cfg
{
	string rootPath = ".";
	string subprojectsPath = "subprojects";
	bool annotate;
	bool bare;
	bool fetch;
}

void main(string[] args)
{
	Cfg cfg;

	with(cfg)
	{
		auto helpInformation = getopt(
			args,
			`root`, `Path to operate in instead of the current working dir`, &rootPath,
			`subprojects`, `Path to subprojects dir instead of Meson default`, &subprojectsPath,
			`annotate`, `Do not perform any action, just print what would be done`, &annotate,
			"bare", `Read only packages contained in the current directory`, &bare,
			"fetch-only", `Only fetch all non-optional dependencies`, &fetch,
		);

		if (helpInformation.helpWanted)
		{
			defaultGetoptPrinter("Usage:",
				helpInformation.options);
		}
	}

	import common;

	auto dub = getDub(cfg);

	if(cfg.fetch)
	{
		dub.fetchAllNonOptionalDependencies;
	}
}
