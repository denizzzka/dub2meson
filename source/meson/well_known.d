module meson.well_known;

import meson.build_file;

struct WellKnownDescriber
{
    string pkgName;
}

immutable WellKnownDescriber[string] describers;

shared static this()
{
    alias D = WellKnownDescriber;

    describers = [
        `vibe-d:data`: D(`vibe-d:data`),
    ];
}

bool addLinesForWellKnown(PackageRootMesonBuildFile meson_build, string name)
{
    switch(name)
    {
        case `vibe-d:data`:
            //FIXME:
            break;

        case `vibe-d:util`:
            //FIXME:
            break;

        default:
            return false;
    }

    return true;
}
