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

module xml.handler;

import xml.attributes;
import xml.except;

interface ContentHandler
{
	/** Receive notification of character data */
	void characters(string ch);

	/** Receive notification of the end of a document */
	void endDocument();

	/** Receive notification of the end of an element */
	void endElement(string uri, string localName, string qName);

	/+/** End of scope of a prefix mapping */
	void endPrefixMapping(string prefix);+/

	/** Receive notification of a processing instruction */
	void processingInstruction(string target, string data);

	//void skippedEntity(string name);

	void startDocument();

	void startElement(string uri, string localName, string qName, 
					  const ref Attributes atts);

	//void startPrefixMapping(string prefix, string uri);
}

interface DTDHandler
{
	void notationDecl(string name, string publicId, string systemId);

	void unparsedEntityDecl(string name, string publicId, string systemId);
}

interface ErrorHandler
{
	void error(SAXParseException exception);

	void fatalError(SAXParseException exception);

	void warning(SAXParseException exception);
}