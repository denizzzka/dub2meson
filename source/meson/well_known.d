module meson.well_known;

import meson.build_file;

struct WellKnownDescriber
{
    string pkgName;
    void function(PackageRootMesonBuildFile meson_file, string packageName) addLines;
}

immutable WellKnownDescriber[] describers;

shared static this()
{
    import std.format: format;
    import meson.mangling: mangle;
    import meson.primitives: Group;

    alias D = WellKnownDescriber;

    describers = [
        D(`vibe-d:data`, (f, n) => f.mapDepVar(n, `vibe_data_dep`)),
        D(`vibe-d:crypto`, (f, n) => f.mapDepVar(n, `vibe_crypto_dep`)),
    ];
}

private void mapDepVar(PackageRootMesonBuildFile meson_file, string packageName, string external_name)
{
    import std.format: format;
    import meson.mangling: mangle;
    import meson.primitives: Group;

    meson_file.addOneLineDirective(
        Group.external_dependencies,
        packageName,
        `%s = %s.get_variable('%s')`.format(
            packageName.mangle(Group.dependencies),
            packageName.mangle(Group.subprojects),
            external_name
        )
    );
}

const(string[]) describersNames()
{
    import std.algorithm;
    import std.array;

    return describers.map!(a => a.pkgName).array;
}

bool addLinesForWellKnown(PackageRootMesonBuildFile meson_build, string packageName)
{
    foreach(ref descr; describers)
    {
        descr.addLines(meson_build, packageName);

        return true;
    }

    return false;
}
