/*
This file is part of Rossignol.

Rossignol is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

Rossignol is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with Rossignol.  If not, see <http://www.gnu.org/licenses/>.

Copyright 2013 Olivier Pisano
*/

module xml.except;

/**
* Encapsulates a general SAX error or warning
*/
class SAXException : Exception
{
public:
	this(string message)
	{
		super(message);
	}
}

/**
* Encapsulates a parser error
*/
final class SAXParseException : SAXException
{
	immutable int m_line;
	immutable int m_col;
	string m_sys;
	string m_pub;

public:
	this(string message, string pub_id, string sys_id, int line, int col)
	{
		super(message);
		m_line = line;
		m_col  = col;
		m_sys  = sys_id;
		m_pub  = pub_id;
	}

	int getColumnNumber() const
	{
		return m_col;
	}

	int getLineNumber() const
	{
		return m_line;
	}

	string getSystemId() const
	{
		return m_sys;
	}

	string getPublicId() const
	{
		return m_pub;
	}
}