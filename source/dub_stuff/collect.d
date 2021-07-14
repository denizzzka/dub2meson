module dub_stuff.collect;

// copied from dub.recipe.packagerecipe and modified

import std.array: appender;
import std.exception: enforce;
import std.range: empty;
import std.file: dirEntries, SpanMode;
import dub.internal.vibecompat.inet.path: NativePath, toNativeString, relativeTo;
import dub.package_: Package;

string[][string] collectFiles(in Package pkg, in string[][string] paths_map, string pattern)
{
	auto base_path = pkg.path;

	string[][string] files;

	import std.typecons : Nullable;

	foreach (suffix, paths; paths_map) {
		foreach (spath; paths) {
			enforce(!spath.empty, "Paths must not be empty strings.");
			auto path = NativePath(spath);

			if (!path.absolute) path = base_path ~ path; // FIXME

			auto pstr = path.toNativeString();
			foreach (d; dirEntries(pstr, pattern, SpanMode.depth)) {
				import std.path : baseName, pathSplitter;
				import std.algorithm.searching : canFind;

				// eliminate any hidden files, or files in hidden directories. But always include
				// files that are listed inside hidden directories that are specifically added to
				// the project.
				if (d.isDir || pathSplitter(d.name[pstr.length .. $])
						   .canFind!(name => name.length && name[0] == '.'))
					continue;

				auto src = NativePath(d.name).relativeTo(base_path);
				files[suffix] ~= src.toNativeString();
			}
		}
	}

	return files;
}
