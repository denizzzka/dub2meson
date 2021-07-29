/// Deals with filesystem
module meson.fs;

import dub.internal.vibecompat.inet.path: NativePath;
import app: cfg;
import vibe.core.file;

private bool[string] wrappedBasePackages;

void rewriteFile(in NativePath filepath, in string content)
{
    if(cfg.verbose)
    {
	import std.stdio;

	writeln(`Write file: `, filepath);
    }

    if(cfg.annotate)
	return;

    const dir = filepath.parentPath;

    if(!dir.existsFile)
	dir.createDirectory;

    filepath.writeFile(cast(const ubyte[]) content);
}

string calcSha256ForFile(NativePath file)
{
    import std.digest;
    import std.digest.sha;

    return file.readFile.sha256Of[].toHexString;
}
