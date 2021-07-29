/// Deals with filesystem
module meson.fs;

import dub.internal.vibecompat.inet.path: NativePath;
import app: cfg;
import vibe.core.file;
import std.typecons: Yes;

private bool[string] wrappedBasePackages;

void rewriteFile(in NativePath filepath, in string content)
{
    if(cfg.verbose)
    {
	import std.stdio;
	import meson.primitives: quote;

	writeln(`Write file: `, filepath.toString.quote);
    }

    if(cfg.annotate)
	return;

    const dir = filepath.parentPath;

    if(!dir.existsFile)
	dir.createDirectory(Yes.recursive);

    filepath.writeFile(cast(const ubyte[]) content);
}

string calcSha256ForFile(NativePath file)
{
    import std.digest;
    import std.digest.sha;

    return file.readFile.sha256Of[].toHexString;
}

class TmpDir
{
    import std.file;
    import std.path;
    import dub.internal.vibecompat.core.file: existsFile;

    const NativePath dir;
    alias dir this;

    this()
    {
	dir = buildPath(tempDir, `dub.repo.`~randomHexString).NativePath;
	dir.toString.mkdirRecurse;
    }

    ~this()
    {
	removeDir();
    }

    void removeDir()
    {
	if(dir.existsFile)
	    dir.toString.rmdirRecurse;
    }
}

//TODO: rewrite ugly code
private string randomHexString()
{
	import vibe.crypto.cryptorand;
	import std.digest;

	ubyte[8] buf;
	secureRNG.read(buf);

	return buf[].toHexString;
}
