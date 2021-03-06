module meson.mangling;

import meson.primitives: Group;
import std.conv: to;

string mangle(string name, Group group) pure
{
    // Special case for sources
    if(
        name == "" &&
        (
            group == Group.sources ||
            group == Group.include_directories ||
            group == Group.string_imports
        )
    )
        return group;

    string suffix;

    with(Group)
    switch(group)
    {
        case sources: suffix = `src`; break;
        case include_directories: suffix = `include`; break;
        case string_imports: suffix = `strings`; break;
        case dependencies: suffix = `dep`; break;
        case external_dependencies: suffix = `dep`; break;
        case subprojects: suffix = `sub`; break;
        case executables: suffix = `exe`; break;
        case libraries: suffix = `lib`; break;

        default:
            assert(false, "Unsupported group: " ~ group.to!string);
    }

    import std.algorithm.iteration: substitute;
    import std.array: array;

    return name.substForbiddenSymbols ~ '_' ~ suffix;
}

string substForbiddenSymbols(string s) pure
{
    import std.algorithm.iteration: substitute;
    import std.array: array;

    return s.
        substitute('-', '_').
        substitute(':', '_').to!string;
}
