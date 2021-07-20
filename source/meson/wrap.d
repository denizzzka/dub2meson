module meson.wrap;

import dub.internal.vibecompat.inet.path: NativePath;
import dub.package_: Package;
import meson.mangling: substForbiddenSymbols;
import app: cfg;
import std.stdio;

private bool[string] wrappedBasePackages;

void createWrapFile(in Package _pkg)
{
    // This function works only with base directories of subpackages
    auto pkg = _pkg.basePackage;

    if(pkg.name in wrappedBasePackages) return;
    wrappedBasePackages[pkg.basePackage.name] = true;

    auto wrapFilePath = cfg.directSubprojectsDir~(pkg.name.substForbiddenSymbols~`.wrap`);

    if(cfg.verbose)
        writefln("Write wrap file for package '%s' ('%s')", pkg.name, wrapFilePath);

    if(!cfg.annotate)
    {
    //TODO: write file content
    //~ [wrap-git]
    //~ url = https://github.com/llvm/llvm-project.git
    //~ depth = 1
    //~ revision = llvmorg-10.0.0-rc2
    }
}
