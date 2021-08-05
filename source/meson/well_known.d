module meson.well_known;

import meson.build_file;

struct WellKnownDescriber
{
    string pkgName;
    void function(PackageRootMesonBuildFile meson_file, string packageName) addLines;
}

immutable WellKnownDescriber[string] describers;

shared static this()
{
    import std.format: format;
    import meson.mangling: mangle;
    import meson.primitives: Group;

    alias D = WellKnownDescriber;

    describers = [
        `vibe-d:data`: D(`vibe-d:data`, (meson_file, packageName){
            meson_file.addOneLineDirective(
                Group.external_dependencies,
                packageName,
                `%s = %s.get_variable('%s')`.format(
                    packageName.mangle(Group.dependencies),
                    packageName.mangle(Group.subprojects),
                    `vibe_data_dep`,
                )
            );
        }),
    ];
}

bool addLinesForWellKnown(PackageRootMesonBuildFile meson_build, string packageName)
{
    const descr = packageName in describers;

    if(descr is null)
        return false;

    descr.addLines(meson_build, packageName);

    return true;
}
