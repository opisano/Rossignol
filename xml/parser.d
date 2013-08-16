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

module xml.parser;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.string;
import std.utf;

import xml.attributes;
import xml.entities;
import xml.except;
import xml.handler;

/**
 * Returns wether a character is considered as whitespace 
 * according to the XML 1.1 specification.
 */
private bool isWhitespace(dchar ch) pure nothrow
{
	return (ch == 0x20 || ch == 0x9 || ch == 0xA || ch == 0xD);
}

/**
 * Returns wether a character is in a range of values
 */
private bool isBetween(dchar ch, dchar lowerBound, dchar upperBound) pure nothrow
{
	return (ch <= upperBound && ch >= lowerBound);
}

/**
 * Returns wether a character is valid as a starting character for a name.
 */
private bool isNameCharStart(dchar ch) pure nothrow
{
	return ((ch == ':')
			|| ch.isBetween('A', 'Z')
			|| ch == '_'
			|| ch.isBetween('a', 'z')
			|| ch.isBetween(0xC0, 0xD6)
			|| ch.isBetween(0xD8, 0xF6)
			|| ch.isBetween(0xF8, 0x2FF)
			|| ch.isBetween(0x370, 0x37D)
			|| ch.isBetween(0x37F, 0x1FFF)
			|| ch.isBetween(0x200C, 0x200D)
			|| ch.isBetween(0x2070, 0x218F)
			|| ch.isBetween(0x2C00, 0x2FEF)
			|| ch.isBetween(0x3001, 0xD7FF)
			|| ch.isBetween(0xF900, 0xFDCF)
			|| ch.isBetween(0xFDF0, 0xFFFD)
			|| ch.isBetween(0x10000, 0xEFFFF));
}

/**
 * Returns wether a character is valid inside a name.
 */
private bool isNameChar(dchar ch) pure nothrow
{
	return ch.isNameCharStart()
		|| (ch == '-')
		|| (ch == '.')
		|| ch.isBetween('0', '9')
		|| (ch == 0xB7)
		|| ch.isBetween(0x300, 0x36F)
		|| ch.isBetween(0x203F, 0x2040);
}

/**
 * Returns wether a name is valid.
 */
private bool isName(string s) pure
in
{
	assert (s.length > 0);
}
body
{
	// check first char
	auto ch = decodeFront(s);
	if (!ch.isNameCharStart())
		return false;

	// check each following char
	while (s.length)
	{
		ch = decodeFront(s);
		if (!ch.isNameChar())
			return false;
	}
	return true;
}

/**
 * returns wether a text is a valid NmToken.
 */
private bool isNmToken(string s) pure
{
	// check each char
	while (s.length)
	{
		auto ch = decodeFront(s);
		if (!ch.isNameChar())
			return false;
	}
	return true;
}

/**
 * Modelizes the state of a XML Parser. 
 * This class serves a as common denominator for all the states
 * the XML parser will while parsing the document.
 */
abstract class ParserState
{
protected:
	Parser m_owner;

	/**
	 * Updates the parser line and column information.
	 */
	final void updatecursor(dchar ch)
	{
		if (ch == '\n')
		{
			m_owner.m_line +=1;
			m_owner.m_col = 1;
		}
		else
		{
			m_owner.m_col += 1;
		}
	}

public:
	this(Parser owner)
	{
		m_owner = owner;
	}

	/**
	 * Parses some XML data.
	 * The state is responsible for firing any event when it successfully
	 * recognizes some content.
	 * It returns the index where it
	*/
	abstract size_t parse(string text);
}

/**
 * Modelizes the state a Parser is in when it starts.
 */
class StartState : ParserState
{
	CommentState			m_commentState;
	DTDState				m_DTDState;
	ProcessInstructionState m_processInstructionState;
	OpeningTagState         m_openingTagState;
	ClosingTagState			m_closingTagState;
	CDataState              m_cdataState;

	// index of beginning of characters
	ptrdiff_t				m_charStartIndex;

public:
	this(Parser owner)
	{
		super(owner);

		m_charStartIndex = -1;

		// create other states
		m_commentState = new CommentState(owner);
		m_DTDState = new DTDState(owner);
		m_processInstructionState = new ProcessInstructionState(owner);
		m_openingTagState = new OpeningTagState(owner);
		m_closingTagState = new ClosingTagState(owner);
		m_cdataState = new CDataState(owner);
	}

	override size_t parse(string text)
	{
		size_t currentIndex;
		string originalText = text;

		if (m_owner.m_contentHandler !is null)
		{
			m_owner.m_contentHandler.startDocument();
		}

		while (currentIndex < text.length)
		{
			text = text[currentIndex..$];
			foreach (size_t i, dchar ch; text)
			{
				updatecursor(ch);
				string s = text;

				// on an opening angle bracket
				if (ch == '<')
				{
					// if there are characters to be sent to contentHandler
					if (m_charStartIndex != -1)
					{
						if (m_owner.m_contentHandler !is null)
						{
							// send them
							m_owner.m_contentHandler.characters(text[m_charStartIndex..i]);
						}
						m_charStartIndex = -1;
					}

					const remainingBytes = text.length - i;

					// is it a comment ?
					if ((remainingBytes >= 3 ) // <!--
							&& (text[i+1..i+4] == "!--"))
					{
						// transfert control to comment state
						m_owner.m_states.insertFront(m_commentState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
					// is it a CDATA section ?
					else if ((remainingBytes >= 8)
							&& (text[i+1..i+9] == "![CDATA["))
					{
						m_owner.m_states.insertFront(m_cdataState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
					else if ((remainingBytes >= 8)
							 && (text[i+1..i+8] == "!DOCTYPE"))
					{
						// transfert control to DTD state
						m_owner.m_states.insertFront(m_DTDState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
					// is it a processing instruction ?
					else if (remainingBytes > 1
							 && (text[i+1] == '?'))
					{
						// transfert control to ProcessInstructon state
						m_owner.m_states.insertFront(m_processInstructionState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
					else if (remainingBytes > 1
							 && isNameCharStart(text[i+1]))
					{
						// transfert control to Opening tag state
						m_owner.m_states.insertFront(m_openingTagState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
					else if (remainingBytes > 1 
							 && text[i+1] == '/')
					{
						// transfert control to Closing tag state
						m_owner.m_states.insertFront(m_closingTagState);
						currentIndex = m_owner.m_states.front.parse(text[i..$]) + i;
						m_owner.m_states.removeFront();
						break;
					}
				}
				else // character data...
				{
					if (m_charStartIndex == -1)
					{
						// mark start index of characters 
						m_charStartIndex = i;
					}
				}
			}
		}

		if (m_owner.m_contentHandler !is null)
		{
			m_owner.m_contentHandler.endDocument();
		}

		return originalText.length;
	}
}

final class CDataState : ParserState
{
public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	in
	{
		assert (text !is null);
		assert (text.length > 8);
		assert ((text[0] == '<')
				&& (text[1] == '!')
				&& (text[2] == '[')
				&& (text[3] == 'C')
				&& (text[4] == 'D')
				&& (text[5] == 'A')
				&& (text[6] == 'T')
				&& (text[7] == 'A')
				&& (text[8] == '['));
	}
	body
	{
		text = text[9..$]; // skip "<![CDATA["
		m_owner.m_col += 9;

		foreach (size_t i, dchar ch; text)
		{
			updatecursor(ch);
			if (ch == ']') // look for ']]>'
			{
				auto remainingBytes = text.length - i;
				if (remainingBytes > 1)
				{
					if (text[i+1] == ']' && text[i+2] == '>')
					{
						m_owner.m_contentHandler.characters(text[0..i]);
						return i + 3 + 9;
					}
				}
			}
		}

		// if the CDATA was not terminated
		throw new SAXParseException("Unterminated CDATA section", null, null, m_owner.m_line, m_owner.m_col);
	}
}

/**
 * Modelizes the State a parser is in when parsing a comment.
 */
final class CommentState : ParserState
{
public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	in
	{
		// check the first chars are the beginning of a comment.
		assert (text !is null);
		assert (text.length > 3);
		assert ((text[0] == '<')
				&& (text[1] == '!')
				&& (text[2] == '-')
				&& (text[3] == '-'));
	}
	body
	{
		text = text[4..$]; // skip '<!--'
		m_owner.m_col += 4;
		foreach (size_t i, dchar ch; text)
		{
			updatecursor(ch);
			if (ch == '-') // look for -->
			{
				const remainingBytes = text.length - i;
				if (remainingBytes)
				{
					if (text[i+1] == '-')
					{
						if (remainingBytes > 1)
						{
							if (text[i+2] == '>')
							{
								return i +3 + 4; // + 4 because we skipped 4 bytes in advance
							}
							else
							{
								throw new SAXParseException("'--' forbiden in comments", 
															 null, null, m_owner.m_line, m_owner.m_col);
							}
						}
					}
				}
			}
		}

		// if the comment was not terminated
		throw new SAXParseException("Unterminated comment", null, null, m_owner.m_line, m_owner.m_col);
	}
}


/**
 * Modelizes the state of the Parser while in a Process Instruction.
 */
final class ProcessInstructionState : ParserState
{
public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	in
	{
		assert (text !is null);
		assert (text.length > 2);
		assert (text[0] == '<');
		assert (text[1] == '?');
	}
	body
	{
		// skip the first 2 bytes '<?'
		text = text[2..$]; 
		m_owner.m_col += 2;

		ptrdiff_t targetEndIndex = -1;
		ptrdiff_t dataStartIndex = -1;

		foreach (size_t i, dchar c; text)
		{
			updatecursor(c);

			if (targetEndIndex == -1)
			{
				
				if (c.isWhitespace())
				{
					targetEndIndex = i;
					continue;
				}
				else if (c == '?')
				{
					auto remainingBytes = text.length - i;
					if (remainingBytes)
					{
						// end of PI
						if (text[i+1] == '>')
						{
							targetEndIndex = i;
							string target = text[0..targetEndIndex];
							if (target.icmp("xml") != 0)
							{
								if (m_owner.m_contentHandler)
								{
									m_owner.m_contentHandler.processingInstruction(target, null);
								}
							}
							return i + 2 + 2; // skpped 2 bytes at start
						}
					}
					else 
					{
						throw new SAXParseException("Unterminated Processing instruction",
													null, null, m_owner.m_line, m_owner.m_col);
					}
				}
			}
			else
			{
				if (c == '?')
				{
					auto remainingBytes = text.length - i;
					if (remainingBytes)
					{
						if (text[i+1] == '>')
						{
							string target = text[0..targetEndIndex];
							if (target.icmp("xml") != 0)
							{
								string data = null;
								if (dataStartIndex != -1)
								{
									data = text[dataStartIndex..i];
								}

								if (m_owner.m_contentHandler)
								{
									m_owner.m_contentHandler.processingInstruction(target, data);
								}
							}
							return i + 2 + 2; // skipped 2 bytes at start
						}
					}
					else
					{
						throw new SAXParseException("Unterminated Processing instruction",
													null, null, m_owner.m_line, m_owner.m_col);
					}
				}
				else if (dataStartIndex == -1 && !c.isWhitespace()) 
				{
					dataStartIndex = i;
				}
			}
		}

		throw new SAXParseException("Unterminated Processing instruction",
									null, null, m_owner.m_line, m_owner.m_col);
	}
}

/**
 * Modelizes the state a parser is when in a DTD.
 * 
 */
final class DTDState : ParserState
{
public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	{
		// level of imbricated angle brackets
		int level = 1;

		updatecursor(text[0]);
		text = text[1..$];

		// simply ignore the content of the DTD since we are not 
		// validating the XML (yet?)
		foreach (size_t i, dchar c; text)
		{
			updatecursor(c);
			final switch (c)
			{
			case '<':
				++level;
				break;
			case '>':
				--level;
				if (level == 0)
				{
					return i + 1 + 1;
				}
			}
		}

		throw new SAXParseException("Unterminated DTD directive",
									null, null, m_owner.m_line, m_owner.m_col);
	}
}

/**
 * Handles the state a parser is when it encounters an opening state.
 */
final class OpeningTagState : ParserState
{
	Appender!(Attribute[]) m_attr_array;

	/**
	 * Adds an attribute to this Attribute array.
	 * Parameters
	 *   - text: xml string being parsed.
	 *   - startIndex: index of the start of attribute in the string.
	 *   - equalIndex: index of the equal sign in the string.
	 *   - openIndex: index of the opening double quote in the string.
	 *   - closeIndex: index of the closing double quote in the string.
	 */
	void appendAttribute(string text, size_t startIndex, size_t equalIndex,
						 size_t openIndex, size_t closeIndex)
	in
	{
		assert(text[startIndex].isNameCharStart());
		assert(startIndex != -1);
		assert(equalIndex != -1);
		assert(openIndex != -1);
		assert(closeIndex != -1);
		assert(startIndex < equalIndex);
		assert(equalIndex < openIndex);
		assert(openIndex < closeIndex);
	}
	body
	{
		if (startIndex == -1)
		{
			throw new SAXParseException("Unnamed attribute encountered", null, null,
										m_owner.m_line, m_owner.m_col);
		}

		if (equalIndex == -1)
		{
			throw new SAXParseException("Expected equal sign for attribute definition", null, null,
										m_owner.m_line, m_owner.m_col);
		}

		size_t index = equalIndex-1;
		while (text[index].isWhitespace())
		{
			index--;
		}

		Attribute attr;
		string qName = text[startIndex..index+1];

		// split qName into uri and localName, if possible
		auto r = findSplit(qName, ":");
		if (!r[1].empty)
		{
			attr.namespace = r[0];
			attr.localName = r[2];
		}
		else 
		{
			attr.localName = qName;
		}

		// split value
		if (openIndex == -1 || closeIndex == -1)
		{
			throw new SAXParseException("Missing attribute value", null, null,
										m_owner.m_line, m_owner.m_col);
		}

		attr.value = text[openIndex+1..closeIndex];
		m_attr_array.put(attr);
	}

public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	{
		ptrdiff_t endNameIndex		= -1;
		ptrdiff_t startAttrIndex	= -1;
		ptrdiff_t eqIndex			= -1;
		ptrdiff_t startQuoteIndex	= -1;
		ptrdiff_t endQuoteIndex		= -1;
		dchar     previousChar;

		m_attr_array.clear();

		text = text[1..$]; 
		m_owner.m_col += 1;
		

		foreach (size_t i, dchar c; text)
		{
			updatecursor(c);

			// if we are still processing tag name
			if (endNameIndex == -1)
			{
				if (!c.isNameChar())
				{
					endNameIndex = i;
				}
				if (c == '>') // 
				{
					if (m_owner.m_contentHandler !is null)
					{
						assert (endNameIndex != -1);

						string qName = text[0..endNameIndex];
						string uri;
						string localName;

						// split qName into uri and localName, if possible
						auto r = findSplit(qName, ":");
						if (!r[1].empty)
						{
							uri = r[0];
							localName = r[2];
						}
						else
						{
							localName = qName;
						}

						// fire event
						Attributes attrs; // empty attributes
						m_owner.m_contentHandler.startElement(uri, localName, qName, attrs);

						if (previousChar == '/')
						{
							m_owner.m_contentHandler.endElement(uri, localName, qName);
						}

						return i + 1 + 1;
					}
				}
			}
			else // if we are processing attributes
			{
				if ((startAttrIndex == -1) && c.isNameCharStart())
				{
					startAttrIndex = i;
				}
				else if (eqIndex == -1 && c == '=')
				{
					eqIndex = i;
				}
				else if (c =='"')
				{
					if (startQuoteIndex == -1)
					{
						startQuoteIndex = i;
					}
					else
					{
						endQuoteIndex = i;
						appendAttribute(text, startAttrIndex, eqIndex, startQuoteIndex, endQuoteIndex);
						startAttrIndex	= -1;
						eqIndex			= -1;
						startQuoteIndex = -1;
						endQuoteIndex	= -1;
					}
				}
				if (c == '>')
				{
					if (m_owner.m_contentHandler !is null)
					{
						// check we have finished parsing an attribute
						if (startAttrIndex != -1 || eqIndex != -1 || startQuoteIndex != -1
								|| endQuoteIndex != -1)
						{
							throw new SAXParseException("Attribute not closed properly", null, null,
														m_owner.m_line, m_owner.m_col);
						}

						string qName = text[0..endNameIndex];
						string uri;
						string localName;

						// split qName into uri and localName, if possible
						auto r = findSplit(qName, ":");
						if (!r[1].empty)
						{
							uri = r[0];
							localName = r[2];
						}
						else
						{
							localName = qName;
						}

						// fire event
						Attributes attrs;
						attrs.attrs = m_attr_array.data();
						m_owner.m_contentHandler.startElement(uri, localName, qName, attrs);

						if (previousChar == '/')
						{
							m_owner.m_contentHandler.endElement(uri, localName, qName);
						}
					}
					return i + 1 + 1;
				}
			}
			previousChar = c;
		}
		throw new SAXParseException("Unterminated tag", null, null, 
									m_owner.m_line, m_owner.m_col);
	}
}

/**
 * Handles the state a parser is when encountering a 
 * closing state
 */
final class ClosingTagState : ParserState
{

public:
	this(Parser owner)
	{
		super(owner);
	}

	override size_t parse(string text)
	{
		text = text[2..$]; // skip '</' chars
		m_owner.m_col += 2;

		foreach (size_t i, dchar ch; text)
		{
			updatecursor(ch);

			if (ch == '>')
			{
				if (m_owner.m_contentHandler !is null)
				{
					string qName = text[0..i];
					string uri;
					string localName;

					// split qName into uri and localName, if possible
					auto r = findSplit(qName, ":");
					if (!r[1].empty)
					{
						uri = r[0];
						localName = r[2];
					}
					else
					{
						localName = qName;
					}

					m_owner.m_contentHandler.endElement(uri, localName, qName);
				}
				return i + 1 + 2;
			}
		}
		
		throw new SAXParseException("Unterminated tag", null, null, 
									m_owner.m_line, m_owner.m_col);
	}
}



final class Parser
{
	// Use a Single linked list as a stack
	SList!ParserState m_states;
	int m_line;
	int m_col;
	ContentHandler m_contentHandler;
	ErrorHandler   m_errorHandler;

public:
	this()
	{
		
	}

	void parse(string text)
	{
		m_states.clear();
		m_states.insertFront(new StartState(this));
// 
		try
		{
			m_states.front.parse(text);
		}
		catch (SAXParseException e)
		{
			if (m_errorHandler !is null)
			{
				m_errorHandler.error(e);
			}
			else
			{
				throw e;
			}
		}
	}

	static string translateEntities(string s)
	{
		auto ampIndex = std.string.indexOf(s, '&');
		if (ampIndex == -1)
		{
			return s;
		}
		else
		{
			auto semicolonIndex = std.string.indexOf(s[ampIndex+1..$], ';') + ampIndex + 1;
			if (semicolonIndex == -1)
			{
				return s;
			}
			else
			{
				dchar code;
				if (s[ampIndex+1] == '#') // if numerical entity
				{
					if (s[ampIndex+2] == 'x') // hexadecimal 
					{
						code = toInt(s[ampIndex+3..semicolonIndex], 16);
					}
					else	// decimal
					{
						code = to!int(s[ampIndex+2..semicolonIndex]);
					}
				}
				else
				{
					auto ent = s[ampIndex+1..semicolonIndex];
					auto found = ent in entitiesMap;
					if (found)
					{
						code = *found;
					}
					else
					{
						code = ' ';
					}
				}

				return s[0..ampIndex] ~ to!string(code) ~ translateEntities(s[semicolonIndex+1..$]);
			}
		}
	}

	unittest
	{
		auto s1 = "Ceci est un test d&apos;utilisation des entit&eacute;s.";
		auto s2 = Parser.translateEntities(s1);
		assert (s2 == "Ceci est un test d'utilisation des entités.");

		auto s3 = "Ceci est un autre test d&#x0027;entit&#233;s.";
		auto s4 = Parser.translateEntities(s3);
		assert (s4 == "Ceci est un autre test d'entités.");

		auto s5 = "Blizzard dépose le nom &quot;The Dark Below&quot;";
		auto s6 = Parser.translateEntities(s5);
		assert (s6 == "Blizzard dépose le nom \"The Dark Below\"");
		
	}

	static string encodeEntities(string s)
	{
		// List of chars to encode as entities
		char[5] entityChars = [ '"', '&', '\'', '<', '>' ];
		string[5] entityStrings = [ "&quot;", "&amp;", "&apos;", "&lt;", "&gt;" ];

		ptrdiff_t binarySearch(char[] haystack, char needle)
		{
			size_t imin = 0;
			size_t imax = haystack.length -1;

			while (imin < imax)
			{
				size_t imid = (imin+imax) >> 1;
				if (haystack[imid] < needle)
					imin = imin+1;
				else
					imax = imid;
			}
			if ((imax == imin) && (haystack[imin] == needle))
				return imin;
			else
				return -1;
		}

		for (size_t index = 0; index < s.length; ++index)
		{
			auto found = binarySearch(entityChars[], s[index]);
			if (found != -1)
			{
				return s[0..index] ~ entityStrings[found] ~ encodeEntities(s[index+1..$]);
			}
		}

		return s;
	}

	unittest
	{
		auto s = "Pierre dépose le nom \"coucou, c'est nous!\"";
		auto expected = "Pierre dépose le nom &quot;coucou, c&apos;est nous!&quot;";
		auto result = encodeEntities(s);
		assert (expected == result);

		s = "<html>";
		expected = "&lt;html&gt;";
		result = encodeEntities(s);
		assert (expected == result);
	}


	@property
	{
		ContentHandler contentHandler()
		{
			return m_contentHandler;
		}

		ContentHandler contentHandler(ContentHandler ch)
		{
			return m_contentHandler = ch;
		}

		ErrorHandler errorHandler()
		{
			return m_errorHandler;
		}

		ErrorHandler errorHandler(ErrorHandler eh)
		{
			return m_errorHandler = eh;
		}
	}
}

unittest
{
	string xmlstr = "<?xml version=\"1.0\" encoding=\"utf-8\"?>"
					"<rss xmlns:a10=\"http://www.w3.org/2005/Atom\" version=\"2.0\">"
					"<!-- commentaire -->"
					"<channel>"
						"<title>PC INpact</title>"
						"<link>http://www.pcinpact.com/</link>"
					"<description>Actualites Informatique</description>"
		            "<emptyTag />"
		            "<content><![CDATA[<cocorico[ ]]></content>"
						"<lastBuildDate>Tue, 25 Jun 2013 17:07:25 Z</lastBuildDate>"
						"<a10:id>http://www.pcinpact.com</a10:id>"
					"</channel>"
					"</rss>";

	class Handler : ContentHandler
	{
		bool m_inTitle;
		bool m_inLink;
		bool m_inDescription;
		bool m_inLastBuildDate;
		bool m_inId;
		bool m_emptyTagOpened;
		bool m_emptyTagClosed;
		bool m_inContent;

		string m_title;
		string m_description;
		string m_link;
		string m_lastBuildDate;
		string m_id;
		string m_content;

	public:
		void characters(string s)
		{
			if (m_inTitle)
				m_title = s;
			else if (m_inLink)
				m_link = s;
			else if (m_inDescription)
				m_description = s;
			else if (m_inLastBuildDate)
				m_lastBuildDate = s;
			else if (m_inId)
				m_id = s;
			else if (m_inContent)
				m_content = s;
		}

		void startDocument() {}
		void endDocument() {}
		void startElement(string uri, string localName, string qName, ref const(Attributes) atts)
		{
			if (qName == "title")
				m_inTitle = true;
			else if (qName == "description")
				m_inDescription = true;
			else if (qName == "lastBuildDate")
				m_inLastBuildDate = true;
			else if (qName == "link")
				m_inLink = true;
			else if (qName == "a10:id")
				m_inId = true;
			else if (qName == "emptyTag")
				m_emptyTagOpened = true;
			else if (qName == "content")
				m_inContent = true;
		}
		void endElement(string uri, string localName, string qName)
		{
			if (qName == "title")
				m_inTitle = false;
			else if (qName == "description")
				m_inDescription = false;
			else if (qName == "lastBuildDate")
				m_inLastBuildDate = false;
			else if (qName == "link")
				m_inLink = false;
			else if (qName == "a10:id")
				m_inId = false;
			else if (qName == "emptyTag")
				m_emptyTagClosed = true;
			else if (qName == "content")
				m_inContent = false;
		}
		void processingInstruction(string target, string data) {}
	}

	auto p = new Parser;
	auto h = new Handler;
	p.contentHandler = h;
	p.parse(xmlstr);

	assert(h.m_title == "PC INpact");
	assert(h.m_link == "http://www.pcinpact.com/");
	assert(h.m_description == "Actualites Informatique");
	assert(h.m_lastBuildDate == "Tue, 25 Jun 2013 17:07:25 Z");
	assert(h.m_id == "http://www.pcinpact.com");
	assert(h.m_emptyTagOpened && h.m_emptyTagClosed);
	assert(h.m_content == "<cocorico[ ");
}