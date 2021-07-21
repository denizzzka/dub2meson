module meson.wrap;

import dub.internal.vibecompat.inet.path: NativePath;
import dub.dependency: PackageDependency;
import meson.mangling: substForbiddenSymbols;
import app: cfg;
import std.stdio;
import std.exception: enforce;
import vibe.core.file;

private bool[string] wrappedBasePackages;

void createWrapFile(in PackageDependency pkgDep)
in(!pkgDep.spec.optional)
{
    import dub.recipe.packagerecipe: getBasePackageName;

    const pkgDepName = pkgDep.name.getBasePackageName;

    if(pkgDepName in wrappedBasePackages) return;
    wrappedBasePackages[pkgDepName] = true;

    auto wrapFilePath = cfg.directSubprojectsDir~(pkgDepName.substForbiddenSymbols~`.wrap`);

    if(cfg.verbose)
        writefln("Write wrap file for package '%s' ('%s')", pkgDepName, wrapFilePath);

    if(!cfg.annotate)
    {
        const wd = pkgDepName in wrapData;
        enforce(wd !is null);

        with(wd)
        wrapFilePath.writeFileUTF8(
            "[wrap-file]\n"~
            //~ `directory = `~packageId~'\n'~
            `source_url = `~url.toString~'\n'~
            `source_hash = `~source_hash~'\n'~
            `patch_directory = `~packageId~"_changes\n"
        );
    }
}

import dub.packagesuppliers;
import dub.dub: defaultRegistryURLs;
import dub.internal.vibecompat.inet.url;
import std.algorithm: map;
import std.array: array;

// Our own suppliers which replaces same from DUB because we don't
// need to download any package, but need to obtain packages URLs

PackageSupplier[] defaultMesonPackageSuppliers()
{
	if(cfg.verbose) writefln("Using dub registry url to get packages places '%s'", defaultRegistryURLs[0]);

	return defaultRegistryURLs.map!getMesonRegistryPackageSupplier.array;

    // TODO: FallbackPackageSupplier declared as "package", need DUB patching
	//~ return [new FallbackPackageSupplier(defaultRegistryURLs.map!getMesonRegistryPackageSupplier.array)];
}

private PackageSupplier getMesonRegistryPackageSupplier(string url)
{
    import std.algorithm: startsWith;

	switch (url.startsWith("dub+", "mvn+", "file://", "https://"))
	{
		case 1:
			return new RegistryMesonSubprojectSupplier(URL(url[4..$]));
		//~ case 2:
			//~ return new MavenRegistryPackageSupplier(URL(url[4..$]));
		//~ case 3:
			//~ return new FileSystemPackageSupplier(NativePath(url[7..$]));
		case 4:
			return new RegistryMesonSubprojectSupplier(URL(url));
		default:
            assert(false, "Registry isn't supported: "~url);
	}
}

class RegistryMesonSubprojectSupplier : RegistryPackageSupplier
{
    immutable packagesPath = "packages";
    const URL registryUrl;

    this(URL registry)
    {
        registryUrl = registry;

        super(registry);
    }

	override void fetchPackage(NativePath path, string packageId, Dependency dep, bool pre_release)
	{
        super.fetchPackage(path, packageId, dep, pre_release);

        WrapData wd;
        wd.packageId = packageId;
        wd.url = genPackageDownloadUrl(packageId, dep, pre_release);
        wd.source_hash = path.calcSha256ForFile;

        wrapData[packageId] = wd;
    }
}

private WrapData[string] wrapData;

struct WrapData
{
    string packageId;
    URL url;
    string source_hash;
}

string calcSha256ForFile(NativePath file)
{
    import std.digest;
    import std.digest.sha;

    return file.readFile.sha256Of[].toHexString;
}
