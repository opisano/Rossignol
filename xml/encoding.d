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
import std.string;

/**
 * Translate a source encoding into UTF-8 representationc
 */
interface EncodingHandler
{
	string decode(const(ubyte)[] input);
}

final class EncodingFactory
{
    static EncodingHandler[string] s_encodingTable;

public:
    static this()
    {
        s_encodingTable["ISO-8859-1"] = new Iso8859_1Handler;
        s_encodingTable["ISO-8859-2"] = new Iso8859_2Handler;
        s_encodingTable["ISO-8859-3"] = new Iso8859_3Handler;
        s_encodingTable["ISO-8859-4"] = new Iso8859_4Handler;
        s_encodingTable["ISO-8859-5"] = new Iso8859_5Handler;
        s_encodingTable["ISO-8859-6"] = new Iso8859_6Handler;
        s_encodingTable["ISO-8859-7"] = new Iso8859_7Handler;
        s_encodingTable["ISO-8859-8"] = new Iso8859_8Handler;
        //s_encodingTable["ISO-8859-9"] = new Iso8859_9Handler;
        s_encodingTable["ISO-8859-15"] = new Iso8859_15Handler;
    }

    static EncodingHandler getEncodingHandler(string encoding)
    in
    {
        // assert encoding is in upper case.
        assert (encoding.toUpper() == encoding);
    }
    body
    {
        return s_encodingTable[encoding];
    }
}

/**
 * Class for converting between an ISO encoding to UTF-8.
 *
 * Since ISO encodings first 128 are ASCII (like utf), special
 * handling is only needed for chars > 127.
 */
abstract class IsoHandler : EncodingHandler
{
protected:
    // chars > 127 (will be specialized in subclasses)
    string[128] m_table;

public:
    final string decode(const(ubyte)[] input)
	{
		auto buffer = appender!string();

		foreach (c; input)
		{
			if (c < 128)
				buffer.put(c);
			else
			{
				auto index = c - 128;
				buffer.put(m_table[index]);
			}
		}

		return buffer.data();
	}
}

/**
 * Translate a ISO-8859-1 text to UTF8
 */
final class Iso8859_1Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u00A1";
        m_table[0xA2-0x80] = "\u00A2";
        m_table[0xA3-0x80] = "\u00A3";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xA5-0x80] = "\u00A5";
        m_table[0xA6-0x80] = "\u00A6";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u00A9";
        m_table[0xAA-0x80] = "\u00AA";
        m_table[0xAB-0x80] = "\u00AB";
        m_table[0xAC-0x80] = "\u00AC";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAE-0x80] = "\u00AE";
        m_table[0xAF-0x80] = "\u00AF";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u00B1";
        m_table[0xB2-0x80] = "\u00B2";
        m_table[0xB3-0x80] = "\u00B3";
        m_table[0xB4-0x80] = "\u00B4";
        m_table[0xB5-0x80] = "\u00B5";
        m_table[0xB6-0x80] = "\u00B6";
        m_table[0xB7-0x80] = "\u00B7";
        m_table[0xB8-0x80] = "\u00B8";
        m_table[0xB9-0x80] = "\u00B9";
        m_table[0xBA-0x80] = "\u00BA";
        m_table[0xBB-0x80] = "\u00BB";
        m_table[0xBC-0x80] = "\u00BC";
        m_table[0xBD-0x80] = "\u00BD";
        m_table[0xBE-0x80] = "\u00BE";
        m_table[0xBF-0x80] = "\u00BF";
        m_table[0xC0-0x80] = "\u00C0";
        m_table[0xC1-0x80] = "\u00C1";
        m_table[0xC2-0x80] = "\u00C2";
        m_table[0xC3-0x80] = "\u00C3";
        m_table[0xC4-0x80] = "\u00C4";
        m_table[0xC5-0x80] = "\u00C5";
        m_table[0xC6-0x80] = "\u00C6";
        m_table[0xC7-0x80] = "\u00C7";
        m_table[0xC8-0x80] = "\u00C8";
        m_table[0xC9-0x80] = "\u00C9";
        m_table[0xCA-0x80] = "\u00CA";
        m_table[0xCB-0x80] = "\u00CB";
        m_table[0xCC-0x80] = "\u00CC";
        m_table[0xCD-0x80] = "\u00CD";
        m_table[0xCE-0x80] = "\u00CE";
        m_table[0xCF-0x80] = "\u00CF";
        m_table[0xD0-0x80] = "\u00D0";
        m_table[0xD1-0x80] = "\u00D1";
        m_table[0xD2-0x80] = "\u00D2";
        m_table[0xD3-0x80] = "\u00D3";
        m_table[0xD4-0x80] = "\u00D4";
        m_table[0xD5-0x80] = "\u00D5";
        m_table[0xD6-0x80] = "\u00D6";
        m_table[0xD7-0x80] = "\u00D7";
        m_table[0xD8-0x80] = "\u00D8";
        m_table[0xD9-0x80] = "\u00D9";
        m_table[0xDA-0x80] = "\u00DA";
        m_table[0xDB-0x80] = "\u00DB";
        m_table[0xDC-0x80] = "\u00DC";
        m_table[0xDD-0x80] = "\u00DD";
        m_table[0xDE-0x80] = "\u00DE";
        m_table[0xDF-0x80] = "\u00DF";
        m_table[0xE0-0x80] = "\u00E0";
        m_table[0xE1-0x80] = "\u00E1";
        m_table[0xE2-0x80] = "\u00E2";
        m_table[0xE3-0x80] = "\u00E3";
        m_table[0xE4-0x80] = "\u00E4";
        m_table[0xE5-0x80] = "\u00E5";
        m_table[0xE6-0x80] = "\u00E6";
        m_table[0xE7-0x80] = "\u00E7";
        m_table[0xE8-0x80] = "\u00E8";
        m_table[0xE9-0x80] = "\u00E9";
        m_table[0xEA-0x80] = "\u00EA";
        m_table[0xEB-0x80] = "\u00EB";
        m_table[0xEC-0x80] = "\u00EC";
        m_table[0xED-0x80] = "\u00ED";
        m_table[0xEE-0x80] = "\u00EE";
        m_table[0xEF-0x80] = "\u00EF";
        m_table[0xF0-0x80] = "\u00F0";
        m_table[0xF1-0x80] = "\u00F1";
        m_table[0xF2-0x80] = "\u00F2";
        m_table[0xF3-0x80] = "\u00F3";
        m_table[0xF4-0x80] = "\u00F4";
        m_table[0xF5-0x80] = "\u00F5";
        m_table[0xF6-0x80] = "\u00F6";
        m_table[0xF7-0x80] = "\u00F7";
        m_table[0xF8-0x80] = "\u00F8";
        m_table[0xF9-0x80] = "\u00F9";
        m_table[0xFA-0x80] = "\u00FA";
        m_table[0xFB-0x80] = "\u00FB";
        m_table[0xFC-0x80] = "\u00FC";
        m_table[0xFD-0x80] = "\u00FD";
        m_table[0xFE-0x80] = "\u00FE";
        m_table[0xFF-0x80] = "\u00FF";
    }
}

final class Iso8859_2Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u0104";
        m_table[0xA2-0x80] = "\u02D8";
        m_table[0xA3-0x80] = "\u0141";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xA5-0x80] = "\u013D";
        m_table[0xA6-0x80] = "\u015A";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u0160";
        m_table[0xAA-0x80] = "\u015E";
        m_table[0xAB-0x80] = "\u0164";
        m_table[0xAC-0x80] = "\u0179";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAE-0x80] = "\u017D";
        m_table[0xAF-0x80] = "\u017B";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u0105";
        m_table[0xB2-0x80] = "\u02DB";
        m_table[0xB3-0x80] = "\u0142";
        m_table[0xB4-0x80] = "\u00B4";
        m_table[0xB5-0x80] = "\u013E";
        m_table[0xB6-0x80] = "\u015B";
        m_table[0xB7-0x80] = "\u02C7";
        m_table[0xB8-0x80] = "\u00B8";
        m_table[0xB9-0x80] = "\u0161";
        m_table[0xBA-0x80] = "\u015F";
        m_table[0xBB-0x80] = "\u0165";
        m_table[0xBC-0x80] = "\u017A";
        m_table[0xBD-0x80] = "\u02DD";
        m_table[0xBE-0x80] = "\u017E";
        m_table[0xBF-0x80] = "\u017C";
        m_table[0xC0-0x80] = "\u0154";
        m_table[0xC1-0x80] = "\u00C1";
        m_table[0xC2-0x80] = "\u00C2";
        m_table[0xC3-0x80] = "\u0102";
        m_table[0xC4-0x80] = "\u00C4";
        m_table[0xC5-0x80] = "\u0139";
        m_table[0xC6-0x80] = "\u0106";
        m_table[0xC7-0x80] = "\u00C7";
        m_table[0xC8-0x80] = "\u010C";
        m_table[0xC9-0x80] = "\u00C9";
        m_table[0xCA-0x80] = "\u0118";
        m_table[0xCB-0x80] = "\u00CB";
        m_table[0xCC-0x80] = "\u011A";
        m_table[0xCD-0x80] = "\u00CD";
        m_table[0xCE-0x80] = "\u00CE";
        m_table[0xCF-0x80] = "\u010E";
        m_table[0xD0-0x80] = "\u0110";
        m_table[0xD1-0x80] = "\u0143";
        m_table[0xD2-0x80] = "\u0147";
        m_table[0xD3-0x80] = "\u00D3";
        m_table[0xD4-0x80] = "\u00D4";
        m_table[0xD5-0x80] = "\u0150";
        m_table[0xD6-0x80] = "\u00D6";
        m_table[0xD7-0x80] = "\u00D7";
        m_table[0xD8-0x80] = "\u0158";
        m_table[0xD9-0x80] = "\u016E";
        m_table[0xDA-0x80] = "\u00DA";
        m_table[0xDB-0x80] = "\u0170";
        m_table[0xDC-0x80] = "\u00DC";
        m_table[0xDD-0x80] = "\u00DD";
        m_table[0xDE-0x80] = "\u0162";
        m_table[0xDF-0x80] = "\u00DF";
        m_table[0xE0-0x80] = "\u0155";
        m_table[0xE1-0x80] = "\u00E1";
        m_table[0xE2-0x80] = "\u00E2";
        m_table[0xE3-0x80] = "\u0103";
        m_table[0xE4-0x80] = "\u00E4";
        m_table[0xE5-0x80] = "\u013A";
        m_table[0xE6-0x80] = "\u0107";
        m_table[0xE7-0x80] = "\u00E7";
        m_table[0xE8-0x80] = "\u010D";
        m_table[0xE9-0x80] = "\u00E9";
        m_table[0xEA-0x80] = "\u0119";
        m_table[0xEB-0x80] = "\u00EB";
        m_table[0xEC-0x80] = "\u011B";
        m_table[0xED-0x80] = "\u00ED";
        m_table[0xEE-0x80] = "\u00EE";
        m_table[0xEF-0x80] = "\u010F";
        m_table[0xF0-0x80] = "\u0111";
        m_table[0xF1-0x80] = "\u0144";
        m_table[0xF2-0x80] = "\u0148";
        m_table[0xF3-0x80] = "\u00F3";
        m_table[0xF4-0x80] = "\u00F4";
        m_table[0xF5-0x80] = "\u0151";
        m_table[0xF6-0x80] = "\u00F6";
        m_table[0xF7-0x80] = "\u00F7";
        m_table[0xF8-0x80] = "\u0159";
        m_table[0xF9-0x80] = "\u016F";
        m_table[0xFA-0x80] = "\u00FA";
        m_table[0xFB-0x80] = "\u0171";
        m_table[0xFC-0x80] = "\u00FC";
        m_table[0xFD-0x80] = "\u00FD";
        m_table[0xFE-0x80] = "\u0163";
        m_table[0xFF-0x80] = "\u02D9";
    }
}

final class Iso8859_3Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u0126";
        m_table[0xA2-0x80] = "\u02D8";
        m_table[0xA3-0x80] = "\u00A3";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xA6-0x80] = "\u0124";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u0130";
        m_table[0xAA-0x80] = "\u015E";
        m_table[0xAB-0x80] = "\u011E";
        m_table[0xAC-0x80] = "\u0134";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAF-0x80] = "\u017B";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u0127";
        m_table[0xB2-0x80] = "\u00B2";
        m_table[0xB3-0x80] = "\u00B3";
        m_table[0xB4-0x80] = "\u00B4";
        m_table[0xB5-0x80] = "\u00B5";
        m_table[0xB6-0x80] = "\u0125";
        m_table[0xB7-0x80] = "\u00B7";
        m_table[0xB8-0x80] = "\u00B8";
        m_table[0xB9-0x80] = "\u0131";
        m_table[0xBA-0x80] = "\u015F";
        m_table[0xBB-0x80] = "\u011F";
        m_table[0xBC-0x80] = "\u0135";
        m_table[0xBD-0x80] = "\u00BD";
        m_table[0xBF-0x80] = "\u017C";
        m_table[0xC0-0x80] = "\u00C0";
        m_table[0xC1-0x80] = "\u00C1";
        m_table[0xC2-0x80] = "\u00C2";
        m_table[0xC4-0x80] = "\u00C4";
        m_table[0xC5-0x80] = "\u010A";
        m_table[0xC6-0x80] = "\u0108";
        m_table[0xC7-0x80] = "\u00C7";
        m_table[0xC8-0x80] = "\u00C8";
        m_table[0xC9-0x80] = "\u00C9";
        m_table[0xCA-0x80] = "\u00CA";
        m_table[0xCB-0x80] = "\u00CB";
        m_table[0xCC-0x80] = "\u00CC";
        m_table[0xCD-0x80] = "\u00CD";
        m_table[0xCE-0x80] = "\u00CE";
        m_table[0xCF-0x80] = "\u00CF";
        m_table[0xD1-0x80] = "\u00D1";
        m_table[0xD2-0x80] = "\u00D2";
        m_table[0xD3-0x80] = "\u00D3";
        m_table[0xD4-0x80] = "\u00D4";
        m_table[0xD5-0x80] = "\u0120";
        m_table[0xD6-0x80] = "\u00D6";
        m_table[0xD7-0x80] = "\u00D7";
        m_table[0xD8-0x80] = "\u011C";
        m_table[0xD9-0x80] = "\u00D9";
        m_table[0xDA-0x80] = "\u00DA";
        m_table[0xDB-0x80] = "\u00DB";
        m_table[0xDC-0x80] = "\u00DC";
        m_table[0xDD-0x80] = "\u016C";
        m_table[0xDE-0x80] = "\u015C";
        m_table[0xDF-0x80] = "\u00DF";
        m_table[0xE0-0x80] = "\u00E0";
        m_table[0xE1-0x80] = "\u00E1";
        m_table[0xE2-0x80] = "\u00E2";
        m_table[0xE4-0x80] = "\u00E4";
        m_table[0xE5-0x80] = "\u010B";
        m_table[0xE6-0x80] = "\u0109";
        m_table[0xE7-0x80] = "\u00E7";
        m_table[0xE8-0x80] = "\u00E8";
        m_table[0xE9-0x80] = "\u00E9";
        m_table[0xEA-0x80] = "\u00EA";
        m_table[0xEB-0x80] = "\u00EB";
        m_table[0xEC-0x80] = "\u00EC";
        m_table[0xED-0x80] = "\u00ED";
        m_table[0xEE-0x80] = "\u00EE";
        m_table[0xEF-0x80] = "\u00EF";
        m_table[0xF1-0x80] = "\u00F1";
        m_table[0xF2-0x80] = "\u00F2";
        m_table[0xF3-0x80] = "\u00F3";
        m_table[0xF4-0x80] = "\u00F4";
        m_table[0xF5-0x80] = "\u0121";
        m_table[0xF6-0x80] = "\u00F6";
        m_table[0xF7-0x80] = "\u00F7";
        m_table[0xF8-0x80] = "\u011D";
        m_table[0xF9-0x80] = "\u00F9";
        m_table[0xFA-0x80] = "\u00FA";
        m_table[0xFB-0x80] = "\u00FB";
        m_table[0xFC-0x80] = "\u00FC";
        m_table[0xFD-0x80] = "\u016D";
        m_table[0xFE-0x80] = "\u015D";
        m_table[0xFF-0x80] = "\u02D9";
    }
}

final class Iso8859_4Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u0104";
        m_table[0xA2-0x80] = "\u0138";
        m_table[0xA3-0x80] = "\u0156";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xA5-0x80] = "\u0128";
        m_table[0xA6-0x80] = "\u013B";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u0160";
        m_table[0xAA-0x80] = "\u0112";
        m_table[0xAB-0x80] = "\u0122";
        m_table[0xAC-0x80] = "\u0166";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAE-0x80] = "\u017D";
        m_table[0xAF-0x80] = "\u00AF";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u0105";
        m_table[0xB2-0x80] = "\u02DB";
        m_table[0xB3-0x80] = "\u0157";
        m_table[0xB4-0x80] = "\u00B4";
        m_table[0xB5-0x80] = "\u0129";
        m_table[0xB6-0x80] = "\u013C";
        m_table[0xB7-0x80] = "\u02C7";
        m_table[0xB8-0x80] = "\u00B8";
        m_table[0xB9-0x80] = "\u0161";
        m_table[0xBA-0x80] = "\u0113";
        m_table[0xBB-0x80] = "\u0123";
        m_table[0xBC-0x80] = "\u0167";
        m_table[0xBD-0x80] = "\u014A";
        m_table[0xBE-0x80] = "\u017E";
        m_table[0xBF-0x80] = "\u014B";
        m_table[0xC0-0x80] = "\u0100";
        m_table[0xC1-0x80] = "\u00C1";
        m_table[0xC2-0x80] = "\u00C2";
        m_table[0xC3-0x80] = "\u00C3";
        m_table[0xC4-0x80] = "\u00C4";
        m_table[0xC5-0x80] = "\u00C5";
        m_table[0xC6-0x80] = "\u00C6";
        m_table[0xC7-0x80] = "\u012E";
        m_table[0xC8-0x80] = "\u010C";
        m_table[0xC9-0x80] = "\u00C9";
        m_table[0xCA-0x80] = "\u0118";
        m_table[0xCB-0x80] = "\u00CB";
        m_table[0xCC-0x80] = "\u0116";
        m_table[0xCD-0x80] = "\u00CD";
        m_table[0xCE-0x80] = "\u00CE";
        m_table[0xCF-0x80] = "\u012A";
        m_table[0xD0-0x80] = "\u0110";
        m_table[0xD1-0x80] = "\u0145";
        m_table[0xD2-0x80] = "\u014C";
        m_table[0xD3-0x80] = "\u0136";
        m_table[0xD4-0x80] = "\u00D4";
        m_table[0xD5-0x80] = "\u00D5";
        m_table[0xD6-0x80] = "\u00D6";
        m_table[0xD7-0x80] = "\u00D7";
        m_table[0xD8-0x80] = "\u00D8";
        m_table[0xD9-0x80] = "\u0172";
        m_table[0xDA-0x80] = "\u00DA";
        m_table[0xDB-0x80] = "\u00DB";
        m_table[0xDC-0x80] = "\u00DC";
        m_table[0xDD-0x80] = "\u0168";
        m_table[0xDE-0x80] = "\u016A";
        m_table[0xDF-0x80] = "\u00DF";
        m_table[0xE0-0x80] = "\u0101";
        m_table[0xE1-0x80] = "\u00E1";
        m_table[0xE2-0x80] = "\u00E2";
        m_table[0xE3-0x80] = "\u00E3";
        m_table[0xE4-0x80] = "\u00E4";
        m_table[0xE5-0x80] = "\u00E5";
        m_table[0xE6-0x80] = "\u00E6";
        m_table[0xE7-0x80] = "\u012F";
        m_table[0xE8-0x80] = "\u010D";
        m_table[0xE9-0x80] = "\u00E9";
        m_table[0xEA-0x80] = "\u0119";
        m_table[0xEB-0x80] = "\u00EB";
        m_table[0xEC-0x80] = "\u0117";
        m_table[0xED-0x80] = "\u00ED";
        m_table[0xEE-0x80] = "\u00EE";
        m_table[0xEF-0x80] = "\u012B";
        m_table[0xF0-0x80] = "\u0111";
        m_table[0xF1-0x80] = "\u0146";
        m_table[0xF2-0x80] = "\u014D";
        m_table[0xF3-0x80] = "\u0137";
        m_table[0xF4-0x80] = "\u00F4";
        m_table[0xF5-0x80] = "\u00F5";
        m_table[0xF6-0x80] = "\u00F6";
        m_table[0xF7-0x80] = "\u00F7";
        m_table[0xF8-0x80] = "\u00F8";
        m_table[0xF9-0x80] = "\u0173";
        m_table[0xFA-0x80] = "\u00FA";
        m_table[0xFB-0x80] = "\u00FB";
        m_table[0xFC-0x80] = "\u00FC";
        m_table[0xFD-0x80] = "\u0169";
        m_table[0xFE-0x80] = "\u016B";
        m_table[0xFF-0x80] = "\u02D9";
    }
}

final class Iso8859_5Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u0401";
        m_table[0xA2-0x80] = "\u0402";
        m_table[0xA3-0x80] = "\u0403";
        m_table[0xA4-0x80] = "\u0404";
        m_table[0xA5-0x80] = "\u0405";
        m_table[0xA6-0x80] = "\u0406";
        m_table[0xA7-0x80] = "\u0407";
        m_table[0xA8-0x80] = "\u0408";
        m_table[0xA9-0x80] = "\u0409";
        m_table[0xAA-0x80] = "\u040A";
        m_table[0xAB-0x80] = "\u040B";
        m_table[0xAC-0x80] = "\u040C";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAE-0x80] = "\u040E";
        m_table[0xAF-0x80] = "\u040F";
        m_table[0xB0-0x80] = "\u0410";
        m_table[0xB1-0x80] = "\u0411";
        m_table[0xB2-0x80] = "\u0412";
        m_table[0xB3-0x80] = "\u0413";
        m_table[0xB4-0x80] = "\u0414";
        m_table[0xB5-0x80] = "\u0415";
        m_table[0xB6-0x80] = "\u0416";
        m_table[0xB7-0x80] = "\u0417";
        m_table[0xB8-0x80] = "\u0418";
        m_table[0xB9-0x80] = "\u0419";
        m_table[0xBA-0x80] = "\u041A";
        m_table[0xBB-0x80] = "\u041B";
        m_table[0xBC-0x80] = "\u041C";
        m_table[0xBD-0x80] = "\u041D";
        m_table[0xBE-0x80] = "\u041E";
        m_table[0xBF-0x80] = "\u041F";
        m_table[0xC0-0x80] = "\u0420";
        m_table[0xC1-0x80] = "\u0421";
        m_table[0xC2-0x80] = "\u0422";
        m_table[0xC3-0x80] = "\u0423";
        m_table[0xC4-0x80] = "\u0424";
        m_table[0xC5-0x80] = "\u0425";
        m_table[0xC6-0x80] = "\u0426";
        m_table[0xC7-0x80] = "\u0427";
        m_table[0xC8-0x80] = "\u0428";
        m_table[0xC9-0x80] = "\u0429";
        m_table[0xCA-0x80] = "\u042A";
        m_table[0xCB-0x80] = "\u042B";
        m_table[0xCC-0x80] = "\u042C";
        m_table[0xCD-0x80] = "\u042D";
        m_table[0xCE-0x80] = "\u042E";
        m_table[0xCF-0x80] = "\u042F";
        m_table[0xD0-0x80] = "\u0430";
        m_table[0xD1-0x80] = "\u0431";
        m_table[0xD2-0x80] = "\u0432";
        m_table[0xD3-0x80] = "\u0433";
        m_table[0xD4-0x80] = "\u0434";
        m_table[0xD5-0x80] = "\u0435";
        m_table[0xD6-0x80] = "\u0436";
        m_table[0xD7-0x80] = "\u0437";
        m_table[0xD8-0x80] = "\u0438";
        m_table[0xD9-0x80] = "\u0439";
        m_table[0xDA-0x80] = "\u043A";
        m_table[0xDB-0x80] = "\u043B";
        m_table[0xDC-0x80] = "\u043C";
        m_table[0xDD-0x80] = "\u043D";
        m_table[0xDE-0x80] = "\u043E";
        m_table[0xDF-0x80] = "\u043F";
        m_table[0xE0-0x80] = "\u0440";
        m_table[0xE1-0x80] = "\u0441";
        m_table[0xE2-0x80] = "\u0442";
        m_table[0xE3-0x80] = "\u0443";
        m_table[0xE4-0x80] = "\u0444";
        m_table[0xE5-0x80] = "\u0445";
        m_table[0xE6-0x80] = "\u0446";
        m_table[0xE7-0x80] = "\u0447";
        m_table[0xE8-0x80] = "\u0448";
        m_table[0xE9-0x80] = "\u0449";
        m_table[0xEA-0x80] = "\u044A";
        m_table[0xEB-0x80] = "\u044B";
        m_table[0xEC-0x80] = "\u044C";
        m_table[0xED-0x80] = "\u044D";
        m_table[0xEE-0x80] = "\u044E";
        m_table[0xEF-0x80] = "\u044F";
        m_table[0xF0-0x80] = "\u2116";
        m_table[0xF1-0x80] = "\u0451";
        m_table[0xF2-0x80] = "\u0452";
        m_table[0xF3-0x80] = "\u0453";
        m_table[0xF4-0x80] = "\u0454";
        m_table[0xF5-0x80] = "\u0455";
        m_table[0xF6-0x80] = "\u0456";
        m_table[0xF7-0x80] = "\u0457";
        m_table[0xF8-0x80] = "\u0458";
        m_table[0xF9-0x80] = "\u0459";
        m_table[0xFA-0x80] = "\u045A";
        m_table[0xFB-0x80] = "\u045B";
        m_table[0xFC-0x80] = "\u045C";
        m_table[0xFD-0x80] = "\u00A7";
        m_table[0xFE-0x80] = "\u045E";
        m_table[0xFF-0x80] = "\u045F";
    }
}

final class Iso8859_6Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xAC-0x80] = "\u060C";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xBB-0x80] = "\u061B";
        m_table[0xBF-0x80] = "\u061F";
        m_table[0xC1-0x80] = "\u0621";
        m_table[0xC2-0x80] = "\u0622";
        m_table[0xC3-0x80] = "\u0623";
        m_table[0xC4-0x80] = "\u0624";
        m_table[0xC5-0x80] = "\u0625";
        m_table[0xC6-0x80] = "\u0626";
        m_table[0xC7-0x80] = "\u0627";
        m_table[0xC8-0x80] = "\u0628";
        m_table[0xC9-0x80] = "\u0629";
        m_table[0xCA-0x80] = "\u062A";
        m_table[0xCB-0x80] = "\u062B";
        m_table[0xCC-0x80] = "\u062C";
        m_table[0xCD-0x80] = "\u062D";
        m_table[0xCE-0x80] = "\u062E";
        m_table[0xCF-0x80] = "\u062F";
        m_table[0xD0-0x80] = "\u0630";
        m_table[0xD1-0x80] = "\u0631";
        m_table[0xD2-0x80] = "\u0632";
        m_table[0xD3-0x80] = "\u0633";
        m_table[0xD4-0x80] = "\u0634";
        m_table[0xD5-0x80] = "\u0635";
        m_table[0xD6-0x80] = "\u0636";
        m_table[0xD7-0x80] = "\u0637";
        m_table[0xD8-0x80] = "\u0638";
        m_table[0xD9-0x80] = "\u0639";
        m_table[0xDA-0x80] = "\u063A";
        m_table[0xE0-0x80] = "\u0640";
        m_table[0xE1-0x80] = "\u0641";
        m_table[0xE2-0x80] = "\u0642";
        m_table[0xE3-0x80] = "\u0643";
        m_table[0xE4-0x80] = "\u0644";
        m_table[0xE5-0x80] = "\u0645";
        m_table[0xE6-0x80] = "\u0646";
        m_table[0xE7-0x80] = "\u0647";
        m_table[0xE8-0x80] = "\u0648";
        m_table[0xE9-0x80] = "\u0649";
        m_table[0xEA-0x80] = "\u064A";
        m_table[0xEB-0x80] = "\u064B";
        m_table[0xEC-0x80] = "\u064C";
        m_table[0xED-0x80] = "\u064D";
        m_table[0xEE-0x80] = "\u064E";
        m_table[0xEF-0x80] = "\u064F";
        m_table[0xF0-0x80] = "\u0650";
        m_table[0xF1-0x80] = "\u0651";
        m_table[0xF2-0x80] = "\u0652";
    }
}

final class Iso8859_7Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA1-0x80] = "\u2018";
        m_table[0xA2-0x80] = "\u2019";
        m_table[0xA3-0x80] = "\u00A3";
        m_table[0xA4-0x80] = "\u20AC";
        m_table[0xA5-0x80] = "\u20AF";
        m_table[0xA6-0x80] = "\u00A6";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u00A9";
        m_table[0xAA-0x80] = "\u037A";
        m_table[0xAB-0x80] = "\u00AB";
        m_table[0xAC-0x80] = "\u00AC";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAF-0x80] = "\u2015";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u00B1";
        m_table[0xB2-0x80] = "\u00B2";
        m_table[0xB3-0x80] = "\u00B3";
        m_table[0xB4-0x80] = "\u0384";
        m_table[0xB5-0x80] = "\u0385";
        m_table[0xB6-0x80] = "\u0386";
        m_table[0xB7-0x80] = "\u00B7";
        m_table[0xB8-0x80] = "\u0388";
        m_table[0xB9-0x80] = "\u0389";
        m_table[0xBA-0x80] = "\u038A";
        m_table[0xBB-0x80] = "\u00BB";
        m_table[0xBC-0x80] = "\u038C";
        m_table[0xBD-0x80] = "\u00BD";
        m_table[0xBE-0x80] = "\u038E";
        m_table[0xBF-0x80] = "\u038F";
        m_table[0xC0-0x80] = "\u0390";
        m_table[0xC1-0x80] = "\u0391";
        m_table[0xC2-0x80] = "\u0392";
        m_table[0xC3-0x80] = "\u0393";
        m_table[0xC4-0x80] = "\u0394";
        m_table[0xC5-0x80] = "\u0395";
        m_table[0xC6-0x80] = "\u0396";
        m_table[0xC7-0x80] = "\u0397";
        m_table[0xC8-0x80] = "\u0398";
        m_table[0xC9-0x80] = "\u0399";
        m_table[0xCA-0x80] = "\u039A";
        m_table[0xCB-0x80] = "\u039B";
        m_table[0xCC-0x80] = "\u039C";
        m_table[0xCD-0x80] = "\u039D";
        m_table[0xCE-0x80] = "\u039E";
        m_table[0xCF-0x80] = "\u039F";
        m_table[0xD0-0x80] = "\u03A0";
        m_table[0xD1-0x80] = "\u03A1";
        m_table[0xD3-0x80] = "\u03A3";
        m_table[0xD4-0x80] = "\u03A4";
        m_table[0xD5-0x80] = "\u03A5";
        m_table[0xD6-0x80] = "\u03A6";
        m_table[0xD7-0x80] = "\u03A7";
        m_table[0xD8-0x80] = "\u03A8";
        m_table[0xD9-0x80] = "\u03A9";
        m_table[0xDA-0x80] = "\u03AA";
        m_table[0xDB-0x80] = "\u03AB";
        m_table[0xDC-0x80] = "\u03AC";
        m_table[0xDD-0x80] = "\u03AD";
        m_table[0xDE-0x80] = "\u03AE";
        m_table[0xDF-0x80] = "\u03AF";
        m_table[0xE0-0x80] = "\u03B0";
        m_table[0xE1-0x80] = "\u03B1";
        m_table[0xE2-0x80] = "\u03B2";
        m_table[0xE3-0x80] = "\u03B3";
        m_table[0xE4-0x80] = "\u03B4";
        m_table[0xE5-0x80] = "\u03B5";
        m_table[0xE6-0x80] = "\u03B6";
        m_table[0xE7-0x80] = "\u03B7";
        m_table[0xE8-0x80] = "\u03B8";
        m_table[0xE9-0x80] = "\u03B9";
        m_table[0xEA-0x80] = "\u03BA";
        m_table[0xEB-0x80] = "\u03BB";
        m_table[0xEC-0x80] = "\u03BC";
        m_table[0xED-0x80] = "\u03BD";
        m_table[0xEE-0x80] = "\u03BE";
        m_table[0xEF-0x80] = "\u03BF";
        m_table[0xF0-0x80] = "\u03C0";
        m_table[0xF1-0x80] = "\u03C1";
        m_table[0xF2-0x80] = "\u03C2";
        m_table[0xF3-0x80] = "\u03C3";
        m_table[0xF4-0x80] = "\u03C4";
        m_table[0xF5-0x80] = "\u03C5";
        m_table[0xF6-0x80] = "\u03C6";
        m_table[0xF7-0x80] = "\u03C7";
        m_table[0xF8-0x80] = "\u03C8";
        m_table[0xF9-0x80] = "\u03C9";
        m_table[0xFA-0x80] = "\u03CA";
        m_table[0xFB-0x80] = "\u03CB";
        m_table[0xFC-0x80] = "\u03CC";
        m_table[0xFD-0x80] = "\u03CD";
        m_table[0xFE-0x80] = "\u03CE";
    }
}

final class Iso8859_8Handler : IsoHandler
{
public:
    this()
    {
        m_table[0x80-0x80] = "\u0080";
        m_table[0x81-0x80] = "\u0081";
        m_table[0x82-0x80] = "\u0082";
        m_table[0x83-0x80] = "\u0083";
        m_table[0x84-0x80] = "\u0084";
        m_table[0x85-0x80] = "\u0085";
        m_table[0x86-0x80] = "\u0086";
        m_table[0x87-0x80] = "\u0087";
        m_table[0x88-0x80] = "\u0088";
        m_table[0x89-0x80] = "\u0089";
        m_table[0x8A-0x80] = "\u008A";
        m_table[0x8B-0x80] = "\u008B";
        m_table[0x8C-0x80] = "\u008C";
        m_table[0x8D-0x80] = "\u008D";
        m_table[0x8E-0x80] = "\u008E";
        m_table[0x8F-0x80] = "\u008F";
        m_table[0x90-0x80] = "\u0090";
        m_table[0x91-0x80] = "\u0091";
        m_table[0x92-0x80] = "\u0092";
        m_table[0x93-0x80] = "\u0093";
        m_table[0x94-0x80] = "\u0094";
        m_table[0x95-0x80] = "\u0095";
        m_table[0x96-0x80] = "\u0096";
        m_table[0x97-0x80] = "\u0097";
        m_table[0x98-0x80] = "\u0098";
        m_table[0x99-0x80] = "\u0099";
        m_table[0x9A-0x80] = "\u009A";
        m_table[0x9B-0x80] = "\u009B";
        m_table[0x9C-0x80] = "\u009C";
        m_table[0x9D-0x80] = "\u009D";
        m_table[0x9E-0x80] = "\u009E";
        m_table[0x9F-0x80] = "\u009F";
        m_table[0xA0-0x80] = "\u00A0";
        m_table[0xA2-0x80] = "\u00A2";
        m_table[0xA3-0x80] = "\u00A3";
        m_table[0xA4-0x80] = "\u00A4";
        m_table[0xA5-0x80] = "\u00A5";
        m_table[0xA6-0x80] = "\u00A6";
        m_table[0xA7-0x80] = "\u00A7";
        m_table[0xA8-0x80] = "\u00A8";
        m_table[0xA9-0x80] = "\u00A9";
        m_table[0xAA-0x80] = "\u00D7";
        m_table[0xAB-0x80] = "\u00AB";
        m_table[0xAC-0x80] = "\u00AC";
        m_table[0xAD-0x80] = "\u00AD";
        m_table[0xAE-0x80] = "\u00AE";
        m_table[0xAF-0x80] = "\u00AF";
        m_table[0xB0-0x80] = "\u00B0";
        m_table[0xB1-0x80] = "\u00B1";
        m_table[0xB2-0x80] = "\u00B2";
        m_table[0xB3-0x80] = "\u00B3";
        m_table[0xB4-0x80] = "\u00B4";
        m_table[0xB5-0x80] = "\u00B5";
        m_table[0xB6-0x80] = "\u00B6";
        m_table[0xB7-0x80] = "\u00B7";
        m_table[0xB8-0x80] = "\u00B8";
        m_table[0xB9-0x80] = "\u00B9";
        m_table[0xBA-0x80] = "\u00F7";
        m_table[0xBB-0x80] = "\u00BB";
        m_table[0xBC-0x80] = "\u00BC";
        m_table[0xBD-0x80] = "\u00BD";
        m_table[0xBE-0x80] = "\u00BE";
        m_table[0xDF-0x80] = "\u2017";
        m_table[0xE0-0x80] = "\u05D0";
        m_table[0xE1-0x80] = "\u05D1";
        m_table[0xE2-0x80] = "\u05D2";
        m_table[0xE3-0x80] = "\u05D3";
        m_table[0xE4-0x80] = "\u05D4";
        m_table[0xE5-0x80] = "\u05D5";
        m_table[0xE6-0x80] = "\u05D6";
        m_table[0xE7-0x80] = "\u05D7";
        m_table[0xE8-0x80] = "\u05D8";
        m_table[0xE9-0x80] = "\u05D9";
        m_table[0xEA-0x80] = "\u05DA";
        m_table[0xEB-0x80] = "\u05DB";
        m_table[0xEC-0x80] = "\u05DC";
        m_table[0xED-0x80] = "\u05DD";
        m_table[0xEE-0x80] = "\u05DE";
        m_table[0xEF-0x80] = "\u05DF";
        m_table[0xF0-0x80] = "\u05E0";
        m_table[0xF1-0x80] = "\u05E1";
        m_table[0xF2-0x80] = "\u05E2";
        m_table[0xF3-0x80] = "\u05E3";
        m_table[0xF4-0x80] = "\u05E4";
        m_table[0xF5-0x80] = "\u05E5";
        m_table[0xF6-0x80] = "\u05E6";
        m_table[0xF7-0x80] = "\u05E7";
        m_table[0xF8-0x80] = "\u05E8";
        m_table[0xF9-0x80] = "\u05E9";
        m_table[0xFA-0x80] = "\u05EA";
        m_table[0xFD-0x80] = "\u200E";
        m_table[0xFE-0x80] = "\u200F";
    }
}

/**
* Translate a ISO-8859-15 text to UTF8
*/
final class Iso8859_15Handler : IsoHandler
{
public:
	this()
	{
		m_table[0x80-0x80] = "\u0080";
		m_table[0x81-0x80] = "\u0081";
		m_table[0x82-0x80] = "\u0082";
		m_table[0x83-0x80] = "\u0083";
		m_table[0x84-0x80] = "\u0084";
		m_table[0x85-0x80] = "\u0085";
		m_table[0x86-0x80] = "\u0086";
		m_table[0x87-0x80] = "\u0087";
		m_table[0x88-0x80] = "\u0088";
		m_table[0x89-0x80] = "\u0089";
		m_table[0x8A-0x80] = "\u008A";
		m_table[0x8B-0x80] = "\u008B";
		m_table[0x8C-0x80] = "\u008C";
		m_table[0x8D-0x80] = "\u008D";
		m_table[0x8E-0x80] = "\u008E";
		m_table[0x8F-0x80] = "\u008F";
		m_table[0x90-0x80] = "\u0090";
		m_table[0x91-0x80] = "\u0091";
		m_table[0x92-0x80] = "\u0092";
		m_table[0x93-0x80] = "\u0093";
		m_table[0x94-0x80] = "\u0094";
		m_table[0x95-0x80] = "\u0095";
		m_table[0x96-0x80] = "\u0096";
		m_table[0x97-0x80] = "\u0097";
		m_table[0x98-0x80] = "\u0098";
		m_table[0x99-0x80] = "\u0099";
		m_table[0x9A-0x80] = "\u009A";
		m_table[0x9B-0x80] = "\u009B";
		m_table[0x9C-0x80] = "\u009C";
		m_table[0x9D-0x80] = "\u009D";
		m_table[0x9E-0x80] = "\u009E";
		m_table[0x9F-0x80] = "\u009F";
		m_table[0xA0-0x80] = "\u00A0";
		m_table[0xA1-0x80] = "\u00A1";
		m_table[0xA2-0x80] = "\u00A2";
		m_table[0xA3-0x80] = "\u00A3";
		m_table[0xA4-0x80] = "\u20AC";
		m_table[0xA5-0x80] = "\u00A5";
		m_table[0xA6-0x80] = "\u0160";
		m_table[0xA7-0x80] = "\u00A7";
		m_table[0xA8-0x80] = "\u0161";
		m_table[0xA9-0x80] = "\u00A9";
		m_table[0xAA-0x80] = "\u00AA";
		m_table[0xAB-0x80] = "\u00AB";
		m_table[0xAC-0x80] = "\u00AC";
		m_table[0xAD-0x80] = "\u00AD";
		m_table[0xAE-0x80] = "\u00AE";
		m_table[0xAF-0x80] = "\u00AF";
		m_table[0xB0-0x80] = "\u00B0";
		m_table[0xB1-0x80] = "\u00B1";
		m_table[0xB2-0x80] = "\u00B2";
		m_table[0xB3-0x80] = "\u00B3";
		m_table[0xB4-0x80] = "\u017D";
		m_table[0xB5-0x80] = "\u00B5";
		m_table[0xB6-0x80] = "\u00B6";
		m_table[0xB7-0x80] = "\u00B7";
		m_table[0xB8-0x80] = "\u017E";
		m_table[0xB9-0x80] = "\u00B9";
		m_table[0xBA-0x80] = "\u00BA";
		m_table[0xBB-0x80] = "\u00BB";
		m_table[0xBC-0x80] = "\u0152";
		m_table[0xBD-0x80] = "\u0153";
		m_table[0xBE-0x80] = "\u0178";
		m_table[0xBF-0x80] = "\u00BF";
		m_table[0xC0-0x80] = "\u00C0";
		m_table[0xC1-0x80] = "\u00C1";
		m_table[0xC2-0x80] = "\u00C2";
		m_table[0xC3-0x80] = "\u00C3";
		m_table[0xC4-0x80] = "\u00C4";
		m_table[0xC5-0x80] = "\u00C5";
		m_table[0xC6-0x80] = "\u00C6";
		m_table[0xC7-0x80] = "\u00C7";
		m_table[0xC8-0x80] = "\u00C8";
		m_table[0xC9-0x80] = "\u00C9";
		m_table[0xCA-0x80] = "\u00CA";
		m_table[0xCB-0x80] = "\u00CB";
		m_table[0xCC-0x80] = "\u00CC";
		m_table[0xCD-0x80] = "\u00CD";
		m_table[0xCE-0x80] = "\u00CE";
		m_table[0xCF-0x80] = "\u00CF";
		m_table[0xD0-0x80] = "\u00D0";
		m_table[0xD1-0x80] = "\u00D1";
		m_table[0xD2-0x80] = "\u00D2";
		m_table[0xD3-0x80] = "\u00D3";
		m_table[0xD4-0x80] = "\u00D4";
		m_table[0xD5-0x80] = "\u00D5";
		m_table[0xD6-0x80] = "\u00D6";
		m_table[0xD7-0x80] = "\u00D7";
		m_table[0xD8-0x80] = "\u00D8";
		m_table[0xD9-0x80] = "\u00D9";
		m_table[0xDA-0x80] = "\u00DA";
		m_table[0xDB-0x80] = "\u00DB";
		m_table[0xDC-0x80] = "\u00DC";
		m_table[0xDD-0x80] = "\u00DD";
		m_table[0xDE-0x80] = "\u00DE";
		m_table[0xDF-0x80] = "\u00DF";
		m_table[0xE0-0x80] = "\u00E0";
		m_table[0xE1-0x80] = "\u00E1";
		m_table[0xE2-0x80] = "\u00E2";
		m_table[0xE3-0x80] = "\u00E3";
		m_table[0xE4-0x80] = "\u00E4";
		m_table[0xE5-0x80] = "\u00E5";
		m_table[0xE6-0x80] = "\u00E6";
		m_table[0xE7-0x80] = "\u00E7";
		m_table[0xE8-0x80] = "\u00E8";
		m_table[0xE9-0x80] = "\u00E9";
		m_table[0xEA-0x80] = "\u00EA";
		m_table[0xEB-0x80] = "\u00EB";
		m_table[0xEC-0x80] = "\u00EC";
		m_table[0xED-0x80] = "\u00ED";
		m_table[0xEE-0x80] = "\u00EE";
		m_table[0xEF-0x80] = "\u00EF";
		m_table[0xF0-0x80] = "\u00F0";
		m_table[0xF1-0x80] = "\u00F1";
		m_table[0xF2-0x80] = "\u00F2";
		m_table[0xF3-0x80] = "\u00F3";
		m_table[0xF4-0x80] = "\u00F4";
		m_table[0xF5-0x80] = "\u00F5";                               
		m_table[0xF6-0x80] = "\u00F6";
		m_table[0xF7-0x80] = "\u00F7";
		m_table[0xF8-0x80] = "\u00F8";
		m_table[0xF9-0x80] = "\u00F9";
		m_table[0xFA-0x80] = "\u00FA";
		m_table[0xFB-0x80] = "\u00FB";
		m_table[0xFC-0x80] = "\u00FC";
		m_table[0xFD-0x80] = "\u00FD";
		m_table[0xFE-0x80] = "\u00FE";
		m_table[0xFF-0x80] = "\u00FF";
	}
}