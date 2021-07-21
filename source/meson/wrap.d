module meson.wrap;

import dub.internal.vibecompat.inet.path: NativePath;
import dub.dependency: PackageDependency;
import meson.mangling: substForbiddenSymbols;
import app: cfg;
import std.stdio;
import std.exception: enforce;

private bool[string] wrappedBasePackages;

void createWrapFile(in PackageDependency pkgDep)
in(!pkgDep.spec.optional)
{
    // This function works only with base directories of subpackages: getBasePackageName
    //~ auto pkg = _pkg.basePackage;

    if(pkgDep.name in wrappedBasePackages) return;
    wrappedBasePackages[pkgDep.name] = true;

    //~ import std.stdio;
    //~ pkgDep.spec.repository.remote.writeln;

    auto wrapFilePath = cfg.directSubprojectsDir~(pkgDep.name.substForbiddenSymbols~`.wrap`);

    if(cfg.verbose)
        writefln("Write wrap file for package '%s' ('%s')", pkgDep.name, wrapFilePath);

    if(!cfg.annotate)
    {
    //TODO: write file content
    //~ [wrap-git]
    //~ url = https://github.com/llvm/llvm-project.git
    //~ depth = 1
    //~ revision = llvmorg-10.0.0-rc2
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
        packagesHttpUrls[packageId] = genPackageDownloadUrl(packageId, dep, pre_release);
        packagesHttpUrls.writeln;

        super.fetchPackage(path, packageId, dep, pre_release);
    }
}

/*private*/ URL[string] packagesHttpUrls;
