module meson.wrap;

import dub.internal.vibecompat.inet.path: NativePath;
import dub.package_: Package;
import app: cfg;

private bool[string] wrappedBasePackages;

void createWrapFile(in Package pkg)
{
    if(pkg.basePackage.name in wrappedBasePackages)
        return;

    if(cfg.verbose)
    {
        import std.stdio;

        if(cfg.verbose)
            writefln("Vrite wrap file for package '%s' ('%s')", pkg.name, cfg.directSubprojectsDir~pkg.name);
    }

    //TODO: write file content
    //~ [wrap-git]
    //~ url = https://github.com/llvm/llvm-project.git
    //~ depth = 1
    //~ revision = llvmorg-10.0.0-rc2

    wrappedBasePackages[pkg.basePackage.name] = true;
}
