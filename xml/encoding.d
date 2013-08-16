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

module xml.encoding;

import std.array;

/**
 * Translate a source encoding into UTF-8 representationc
 */
interface EncodingHandler
{
	string decode(const(ubyte)[] input);
}

enum Encoding
{
	iso8859_15,
	utf_8
}


final class UTF8Handler : EncodingHandler
{
public:
	string decode(const(ubyte)[] input)
	{
		return cast(string)input;
	}
}

final class Iso8859_15Hander : EncodingHandler
{
	static string[128] s_table;
public:
	static this()
	{
		s_table[0x80-0x80] = "\u0080";
		s_table[0x81-0x80] = "\u0081";
		s_table[0x82-0x80] = "\u0082";
		s_table[0x83-0x80] = "\u0083";
		s_table[0x84-0x80] = "\u0084";
		s_table[0x85-0x80] = "\u0085";
		s_table[0x86-0x80] = "\u0086";
		s_table[0x87-0x80] = "\u0087";
		s_table[0x88-0x80] = "\u0088";
		s_table[0x89-0x80] = "\u0089";
		s_table[0x8A-0x80] = "\u008A";
		s_table[0x8B-0x80] = "\u008B";
		s_table[0x8C-0x80] = "\u008C";
		s_table[0x8D-0x80] = "\u008D";
		s_table[0x8E-0x80] = "\u008E";
		s_table[0x8F-0x80] = "\u008F";
		s_table[0x90-0x80] = "\u0090";
		s_table[0x91-0x80] = "\u0091";
		s_table[0x92-0x80] = "\u0092";
		s_table[0x93-0x80] = "\u0093";
		s_table[0x94-0x80] = "\u0094";
		s_table[0x95-0x80] = "\u0095";
		s_table[0x96-0x80] = "\u0096";
		s_table[0x97-0x80] = "\u0097";
		s_table[0x98-0x80] = "\u0098";
		s_table[0x99-0x80] = "\u0099";
		s_table[0x9A-0x80] = "\u009A";
		s_table[0x9B-0x80] = "\u009B";
		s_table[0x9C-0x80] = "\u009C";
		s_table[0x9D-0x80] = "\u009D";
		s_table[0x9E-0x80] = "\u009E";
		s_table[0x9F-0x80] = "\u009F";
		s_table[0xA0-0x80] = "\u00A0";
		s_table[0xA1-0x80] = "\u00A1";
		s_table[0xA2-0x80] = "\u00A2";
		s_table[0xA3-0x80] = "\u00A3";
		s_table[0xA4-0x80] = "\u20AC";
		s_table[0xA5-0x80] = "\u00A5";
		s_table[0xA6-0x80] = "\u0160";
		s_table[0xA7-0x80] = "\u00A7";
		s_table[0xA8-0x80] = "\u0161";
		s_table[0xA9-0x80] = "\u00A9";
		s_table[0xAA-0x80] = "\u00AA";
		s_table[0xAB-0x80] = "\u00AB";
		s_table[0xAC-0x80] = "\u00AC";
		s_table[0xAD-0x80] = "\u00AD";
		s_table[0xAE-0x80] = "\u00AE";
		s_table[0xAF-0x80] = "\u00AF";
		s_table[0xB0-0x80] = "\u00B0";
		s_table[0xB1-0x80] = "\u00B1";
		s_table[0xB2-0x80] = "\u00B2";
		s_table[0xB3-0x80] = "\u00B3";
		s_table[0xB4-0x80] = "\u017D";
		s_table[0xB5-0x80] = "\u00B5";
		s_table[0xB6-0x80] = "\u00B6";
		s_table[0xB7-0x80] = "\u00B7";
		s_table[0xB8-0x80] = "\u017E";
		s_table[0xB9-0x80] = "\u00B9";
		s_table[0xBA-0x80] = "\u00BA";
		s_table[0xBB-0x80] = "\u00BB";
		s_table[0xBC-0x80] = "\u0152";
		s_table[0xBD-0x80] = "\u0153";
		s_table[0xBE-0x80] = "\u0178";
		s_table[0xBF-0x80] = "\u00BF";
		s_table[0xC0-0x80] = "\u00C0";
		s_table[0xC1-0x80] = "\u00C1";
		s_table[0xC2-0x80] = "\u00C2";
		s_table[0xC3-0x80] = "\u00C3";
		s_table[0xC4-0x80] = "\u00C4";
		s_table[0xC5-0x80] = "\u00C5";
		s_table[0xC6-0x80] = "\u00C6";
		s_table[0xC7-0x80] = "\u00C7";
		s_table[0xC8-0x80] = "\u00C8";
		s_table[0xC9-0x80] = "\u00C9";
		s_table[0xCA-0x80] = "\u00CA";
		s_table[0xCB-0x80] = "\u00CB";
		s_table[0xCC-0x80] = "\u00CC";
		s_table[0xCD-0x80] = "\u00CD";
		s_table[0xCE-0x80] = "\u00CE";
		s_table[0xCF-0x80] = "\u00CF";
		s_table[0xD0-0x80] = "\u00D0";
		s_table[0xD1-0x80] = "\u00D1";
		s_table[0xD2-0x80] = "\u00D2";
		s_table[0xD3-0x80] = "\u00D3";
		s_table[0xD4-0x80] = "\u00D4";
		s_table[0xD5-0x80] = "\u00D5";
		s_table[0xD6-0x80] = "\u00D6";
		s_table[0xD7-0x80] = "\u00D7";
		s_table[0xD8-0x80] = "\u00D8";
		s_table[0xD9-0x80] = "\u00D9";
		s_table[0xDA-0x80] = "\u00DA";
		s_table[0xDB-0x80] = "\u00DB";
		s_table[0xDC-0x80] = "\u00DC";
		s_table[0xDD-0x80] = "\u00DD";
		s_table[0xDE-0x80] = "\u00DE";
		s_table[0xDF-0x80] = "\u00DF";
		s_table[0xE0-0x80] = "\u00E0";
		s_table[0xE1-0x80] = "\u00E1";
		s_table[0xE2-0x80] = "\u00E2";
		s_table[0xE3-0x80] = "\u00E3";
		s_table[0xE4-0x80] = "\u00E4";
		s_table[0xE5-0x80] = "\u00E5";
		s_table[0xE6-0x80] = "\u00E6";
		s_table[0xE7-0x80] = "\u00E7";
		s_table[0xE8-0x80] = "\u00E8";
		s_table[0xE9-0x80] = "\u00E9";
		s_table[0xEA-0x80] = "\u00EA";
		s_table[0xEB-0x80] = "\u00EB";
		s_table[0xEC-0x80] = "\u00EC";
		s_table[0xED-0x80] = "\u00ED";
		s_table[0xEE-0x80] = "\u00EE";
		s_table[0xEF-0x80] = "\u00EF";
		s_table[0xF0-0x80] = "\u00F0";
		s_table[0xF1-0x80] = "\u00F1";
		s_table[0xF2-0x80] = "\u00F2";
		s_table[0xF3-0x80] = "\u00F3";
		s_table[0xF4-0x80] = "\u00F4";
		s_table[0xF5-0x80] = "\u00F5";                               
		s_table[0xF6-0x80] = "\u00F6";
		s_table[0xF7-0x80] = "\u00F7";
		s_table[0xF8-0x80] = "\u00F8";
		s_table[0xF9-0x80] = "\u00F9";
		s_table[0xFA-0x80] = "\u00FA";
		s_table[0xFB-0x80] = "\u00FB";
		s_table[0xFC-0x80] = "\u00FC";
		s_table[0xFD-0x80] = "\u00FD";
		s_table[0xFE-0x80] = "\u00FE";
		s_table[0xFF-0x80] = "\u00FF";
	}

	string decode(const(ubyte)[] input)
	{
		auto buffer = appender!string();

		foreach (c; input)
		{
			if (c < 128)
				buffer.put(c);
			else
			{
				auto index = 128 - c;
				buffer.put(s_table[index]);
			}
		}

		return buffer.data();
	}
}