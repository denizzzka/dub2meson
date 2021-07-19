module meson.mangling;

import meson.primitives: Group;

string mangle(string name, Group group) pure
{
    import std.conv: to;

    string suffix;

    with(Group)
    switch(group)
    {
        case sources: suffix = `_src`; break;
        case include_directories: suffix = `_include_dirs`; break;
        case string_imports: suffix = `_strings`; break;
        case dependencies: suffix = `_dep`; break;
        case external_dependencies: suffix = `_dep`; break;
        case subprojects: suffix = `_sub`; break;

        default:
            assert(false, "Unsupported group: " ~ group.to!string);
    }

    return name ~ suffix;
}
