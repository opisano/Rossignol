/*
This file is part of Rossignol.

Foobar is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Foobar is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Foobar.  If not, see <http://www.gnu.org/licenses/>.

Copyright 2013 Olivier Pisano
*/

module properties;

/*
 * This module implements reading and writing of properties files.
 * Properties file are a equivalent of Java .properties files or .ini files
 * (minus there is no section structures).
 *
 * File structure are juste lines of "Key = value".
 */

import std.algorithm;
import std.file;
import std.range;
import std.stdio;
import std.string;

// For the moment, the Properties type is just an alias to a hashmap of 
// string, string. If extra functionality is need, we can 
alias string[string] Properties;

/**
 * Copies all the content of a Properties instance into another.
 */
void addAll(ref Properties props, const Properties other)
{
	foreach (key; other.byKey())
	{
		props[key] = other[key];
	}
}

/**
 * Writes the content of a Properties instance into a file.
 */
void writeToFile(const ref Properties props, string filename)
{
	// sort keys
	auto keys = props.keys;
	sort(keys);

	// open output file
	auto f = File(filename ~ ".bak", "w");

	scope (success)
	{
		if (exists(filename))
		{
			remove(filename);
		}
		rename(filename ~ ".bak", filename);
	}

	foreach (k; keys)
	{
		f.writefln("%s = %s", k, props[k]);
	}
	f.close();
}

/**
 * Reads the content of a Properties instance from a file.
 */
void loadFromFile(out Properties props, string filename)
{
	auto f = File(filename, "r");

	foreach (line; f.byLine())
	{
		// skip empty lines and comments
		line = line.strip();
		if (line.empty || line.startsWith("#"))
		{
			continue;
		}

		auto r = line.findSplit("=");

		// '=' was not found in line
		if (r[1].empty || r[2].empty)
		{
			continue;
		}
		
		// put (key, value) into properties
		string key   = r[0].strip().idup;
		string value = r[2].strip().idup;
		props[key] = value;
	}
}