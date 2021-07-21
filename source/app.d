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
	bool overrideMesonBuildFiles;
	bool verbose;

	import dub.internal.vibecompat.inet.path: NativePath;

	NativePath directSubprojectsDir() const
	{
		return NativePath(rootPath ~ subprojectsPath);
	}
}

private Cfg _cfg;

ref const(Cfg) cfg() { return _cfg; }

import dub.internal.vibecompat.inet.path: NativePath;

void main(string[] args)
{
	with(_cfg)
	{
		//TODO: add --registry=VALUE and --skip-registry=VALUE
		auto helpInformation = getopt(
			args,
			`root`, `Path to operate in instead of the current working dir`, &rootPath,
			`subprojects`, `Path to subprojects dir instead of Meson default`, &subprojectsPath,
			`annotate`, `Do not perform any action, just print what would be done`, &annotate,
			"bare", `Read only packages contained in the current directory`, &bare,
			"fetch-only", `Fetch all non-optional dependencies and exit`, &fetch,
			"cache", `Puts any fetched packages in the specified location [local|system|user]`, &placementLocation,
			"override", `Generate files for already mesonified packages and its dependencies`, &overrideMesonBuildFiles,
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
	import dub.project: PlacementLocation;

	if(cfg.fetch)
	{
		// Just fetching all dependencies

		auto dub = createDub(cfg, null, cfg.placementLocation);
		dub.fetchAllNonOptionalDependencies;

		return;
	}
	else
	{
		// Fetching all dependencies into temporary package manager to obtain all versions and URLs

		import dub.packagemanager: PackageManager;
		import vibe.core.file: createDirectory;

		auto tmpPath = NativePath(`/tmp/dub.repo.`~randomString);
		tmpPath.createDirectory;
		//FIXME: remove tmp dir after using

		auto pm = new PackageManager(tmpPath, tmpPath, tmpPath, false);
		auto dub = createDub(cfg, pm, PlacementLocation.user);
		dub.fetchAllNonOptionalDependencies;

		import meson.wrap: packagesHttpUrls;
		packagesHttpUrls.writeln;

		// All other magic is here
		dub.createMesonFiles(cfg);
	}

	import meson.build_file: RootMesonBuildFile;

	RootMesonBuildFile.rewriteFiles();
}

//FIXME: ugly code
private string randomString()
{
	import vibe.crypto.cryptorand;
	import std.digest;

	ubyte[8] buf;
	secureRNG.read(buf);

	return buf[].toHexString;
}
