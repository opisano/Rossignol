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

module feed;

/**
 *
 * This module implements the handling of Feeds objects: XML parsing from 
 * various formats.
 *
 * author: Olivier Pisano.
 *
 */

import core.time;

import std.algorithm;
import std.array;
import std.container;
import std.conv;
import std.datetime;
import std.exception;
import std.file;
import std.net.curl;
import std.regex;
import std.string;

import std.c.time;

import org.eclipse.swt.graphics.Image;

import date;
import text;
import xml.attributes;
import xml.except;
import xml.handler;
import xml.parser;

/**
 * Modelizes an article in a Feed.
 * This class is immutable, since articles are published by websites and are not to 
 * be modified by Rossignol users themselves.
 */
final class FeedArticle
{
    // Article title
	string m_title;

    // Article author
	string m_author;

    // Article description
	string m_description;

    // Article url
	string m_url;

    // last date of modification
	time_t m_time;

public:
	this(string title, string author, string description, string url, time_t time) immutable
	{
		m_title		  = title;
		m_author	  = author;
		m_description = description;
		m_url		  = url;
		m_time        = time;
	}

	string getTitle() immutable pure nothrow
	{
		return m_title;
	}

	string getAuthor() immutable pure nothrow
	{
		return m_author;
	}

	string getURL() immutable pure nothrow
	{
		return m_url;
	}

	string getDescription() immutable pure nothrow
	{
		return m_description;
	}

	time_t getTime() immutable pure nothrow
	{
		return m_time;
	}

    /**
     * Serializes an article in XML format.
     */
	string toXML() immutable
	{
		return format("<article title=\"%s\" author=\"%s\" description=\"%s\" url=\"%s\" time=\"%s\"/>",
					  xml.parser.Parser.encodeEntities(m_title), 
					  xml.parser.Parser.encodeEntities(m_author), 
					  xml.parser.Parser.encodeEntities(m_description), 
					  m_url, 
					  m_time);
	}
}

// For simplicity, create an alias. 
alias immutable(FeedArticle) Article;


/**
 * This class presents a thread-safe abstraction of a Feed, independantly 
 * of its format (RSS, Atom or anything).
 * 
 * This class only provides the most common denominator between all the 
 * feed formats supported in Rossignol, therefore I am rather reluctant 
 * to add any new functionality to this class since it could prevent 
 * the adoption of a new feed format if it were not to support this 
 * functionality.
 */
final synchronized class FeedInfo
{
    // name of the feed
	string		m_name;
    // link to the feed website
	string		m_link;
    // url where to load the feed (
	string      m_url;
    // Articles in the feed
	Article[]	m_articles;
    // url to the feed icon
	string      m_icon;

	// cached for performance reasons
	time_t      m_mostRecentArticle; 

	/**
	 * Used when deserializing
	 */
	void appendArticle(Article art)
	{
		m_articles ~= art;
	}

public:
	this(string name, string url, string link, Article[] articles)
	{
		m_name = name;
		m_url = url;
		m_link = link;
		m_articles = articles;
	}

	string getName() const
	{
		return m_name;
	}

	string getLink() const
	{
		return m_link;
	}

	string getURL() const
	{
		return m_url;
	}

	Article[] getArticles() const
	{
		return m_articles;
	}

	string getIcon() const
	{
		return m_icon;
	}

	void setIcon(string ico)
	in
	{
		assert (ico !is null);
	}
	body
	{
		m_icon = ico;
	}

    /**
     * Adds articles to this feed.
     */
	size_t add(Article[] articles)
	{
		// get our most recent article time (lazy fashioned)
		if (m_mostRecentArticle == time_t.init)
		{
			m_mostRecentArticle = m_articles
									.map!((a) => a.getTime())
									.reduce!max;
		}

		// filter the articles more recent than our most recent article
		auto newArticles = articles.filter!((a) => a.getTime() > m_mostRecentArticle);
		
		size_t added;
		if (!newArticles.empty)
		{
            // use an Appender, since we may put add many articles 
            // that may trigger multiple heap allocations
            auto p = appender(m_articles);
			foreach (a; newArticles)
			{
		        p.put(a);
				added++;
			}
            m_articles = p.data();

			// update our most recent article time
			m_mostRecentArticle = newArticles.map!((a) => a.getTime())
											 .reduce!max;
		}
		return added;
	}

	/**
	 * Removes old articles.
	 * 
	 * Articles older than the date passed in parameter are 
	 * removed from this feed.
	 */
	void removeOldArticles(time_t threshold)
	out
	{
		foreach (art; m_articles)
		{
			assert (art.getTime() >= threshold);
		}
	}
	body
	{
        // since Article is immutable, we create a copy instead of 
		auto moreRecent = appender!(Article[])();
		foreach (a; m_articles)
		{
			if (a.getTime() >= threshold)
				moreRecent.put(a);
		}
		m_articles = moreRecent.data();
	}

    /**
     * Serializes A feed as XML.
     */
	string toXML() const
	{
		auto buffer = appender!string(format("<feed name=\"%s\" url=\"%s\" link=\"%s\" ", xml.parser.Parser.encodeEntities(m_name), m_url, m_link));
		if (!m_icon.empty)
		{
			buffer ~= format("icon=\"%s\"", m_icon);
		}
		buffer ~= ">\n";
		foreach (article; m_articles)
		{
			buffer ~= format("\t%s\n", article.toXML());
		}
		buffer ~= "</feed>\n";

		return buffer.data();
	}
}

/** 
 * XML deserialization
 */
shared(FeedInfo)[] loadFeedsFromXML(string filename)
{
	shared(FeedInfo)[] result;

	class Handler : ContentHandler
	{
		shared FeedInfo m_currentFeed;

	public:

		void startDocument() { }
		void endDocument() { }

		void startElement(string uri, string localName, string qName, ref const(Attributes) atts)
		{
			if (qName == "feed")
			{
				string name = xml.parser.Parser.translateEntities(atts.getValue("name"));
				string url = atts.getValue("url");
				string link = atts.getValue("link");
				result ~= new shared FeedInfo(name, url, link, []);

				auto iconIndex = atts.getIndex("icon");
				if (iconIndex != -1)
					result.back.setIcon(atts.getValue("icon"));
			}
			else if (qName == "article")
			{
				string title = xml.parser.Parser.translateEntities(atts.getValue("title"));
				string author = xml.parser.Parser.translateEntities(atts.getValue("author"));
				string url = atts.getValue("url");
				string description;
				auto index = atts.getIndex("description");
				if (index != -1)
				{
					description = xml.parser.Parser.translateEntities(atts.getValue("description"));
				}
				time_t t = to!time_t(atts.getValue("time"));

				result.back.appendArticle(new Article(title, author, description, url, t));
			}
		}

		void characters(string s)
		{
		}

		void endElement(string uri, string localName, string qName)
		{
		}
		
		void processingInstruction(string target, string data)
		{
		}
	}

	string fileContent = readText(filename);
	auto parser = new xml.parser.Parser;
	auto handler = new Handler;
	parser.contentHandler = handler;
	parser.parse(fileContent);

	return result;
}

/**
 * Abstract Base class for Feed parsing strategy.
 *
 * Feed decoding is done using the Strategy design pattern. All 
 * the parsing classes derive from this class, which is an XML content handler
 * (we can safely assume that all the feed formats are based on XML). 
 */
abstract class FeedStrategy : ContentHandler
{
protected:
	FeedContentHandler m_owner;
public:

	/**
	 * Creates a new strategy for the FeedContentHandler passed in parameter.
	 */
	this(FeedContentHandler owner)
	{
		m_owner = owner;
	}
}

/**
 * Implements the strategy of parsing a feed before knowing its 
 * actual format.
 * This class should only be used at first to discover the type 
 * of a feed (RSS or ATOM) and should then delegate the parsing to
 * a specialized class. 
 */
class StartStrategy : FeedStrategy
{
	bool m_firstElement;
public:
	this(FeedContentHandler owner)
	{
		super(owner);
		m_firstElement = true;
	}

	void startDocument()
	{
		// Nothing to do
	}

	void endDocument()
	{
		// Nothing to do
	}

	void characters(string text)
	{
		// Nothing to do
	}

	/**
	 * Reacts to the first element encountered while parsing the feed.
	 */
	void startElement(string uri, string localName, string qName,
					  const ref Attributes atts)
	in
	{
		assert (m_firstElement == true);
	}
	out
	{
		assert (m_firstElement == false);
	}
	body
	{
		// if the feed is a RSS feed
		if (qName == "rss")
		{
			// get rss version
			string vers;
			auto versionIndex = atts.getIndex("version");
			// if no version attribute is provided
			if (versionIndex == -1)
			{
				// choose the most simple format
				vers = "0.91";
			}
			else
			{
				vers = atts.getValue(versionIndex);
			}

			if (vers == "2.0")
			{
				m_owner.setStrategy(new RSS20Strategy(m_owner));
			}
		}
		else if (qName == "feed")
		{
			m_owner.setStrategy(new AtomStrategy(m_owner));
		}
		else if (localName == "RDF")
		{
			m_owner.setStrategy(new RSS10Strategy(m_owner));
		}

		m_firstElement = false;
	}

	void endElement(string uri, string localName, string qName)
	{
		assert(0);
	}

	void processingInstruction(string target, string data)
	{
	}
}

/**
 * Strategy pattern for parsing Atom documents.
 * Cf. RFC4287 at http://tools.ietf.org/html/rfc4287 
 */
final class AtomStrategy : FeedStrategy
{
	/**
	 * Modelizes a Person construct (section 3.2)
	 */
	static struct AtomPerson
	{
		string name;
		string uri;
		string email;
	}

	/**
	 * Modelizes a Link construct (section 4.2.7)
	 */
	static struct AtomLink
	{
		string href;
		string rel = "alternate";
		string type;
		string title;
		string hreflang;
		size_t length;
	}

	/**
	 * Modelizes a feed construct (section 4.1.1)
	 */
	static struct AtomFeed
	{
		Appender!(AtomPerson[])	  authors;
		Appender!(AtomCategory[]) categories;
		Appender!(AtomPerson[])	  contributors;
		string          icon;
		string          id;
		Appender!(AtomLink[])     links;
		string          logo;
		string          rights;
		string          subtitle;
		string          title;
		string          updated;
		Appender!(AtomEntry[]) entries;
	}

	/** 
	 * Modelizes a category (section 4.2.2)
	 */
	static struct AtomCategory
	{
		string term;
		string label;
	}

	/**
	 * Modelizes an entry (section 4.1.2)
	 */
	static struct AtomEntry
	{
		Appender!(AtomPerson[])	authors;
		Appender!(AtomCategory[])	categories;
		Appender!(AtomPerson[])	contributors;
		string			id;
		Appender!(AtomLink[])		links;
		string          published;
		string          rights;
		string          summary;
		string			title;
		string			updated;
	}

	// These flags indicate we are in an open tag

	bool m_inEntry;
	bool m_inTitle;
	bool m_inAuthor;
	bool m_inContributor;
	bool m_inIcon;
	bool m_inLogo;
	bool m_inPublished;
	bool m_inUpdated;
	bool m_inName;
	bool m_inUri;
	bool m_inEmail;
	bool m_inLink;
	bool m_inSummary;
	bool m_inId;
	bool m_inRights;
	bool m_inSubtitle;

	AtomPerson m_currentPerson;
	AtomFeed   m_currentFeed;
	AtomEntry  m_currentEntry;

public:
	this(FeedContentHandler owner)
	{
		super(owner);
	}

	void characters(string s)
	{
		if (m_inAuthor || m_inContributor)
		{
			if (m_inName)
			{
				m_currentPerson.name = s;
			}
			else if (m_inEmail)
			{
				m_currentPerson.email = s;
			}
			else if (m_inUri)
			{
				m_currentPerson.uri = s;
			}
		}
		else if (m_inEntry)
		{
			if (m_inTitle)
			{
				m_currentEntry.title = s;
			}
			else if (m_inPublished)
			{
				m_currentEntry.published = s;
			}
			else if (m_inUpdated)
			{
				m_currentEntry.updated = s;
			}
			else if (m_inSummary)
			{
				m_currentEntry.summary = s;
			}
			else if (m_inId)
			{
				m_currentEntry.id = s;
			}
			else if (m_inRights)
			{
				m_currentEntry.rights = s;
			}
			else if (m_inRights)
			{
				m_currentEntry.summary = s;
			}
		}
		else // in feed
		{
			if (m_inIcon)
			{
				m_currentFeed.icon = s;
			}
			else if (m_inId)
			{
				m_currentFeed.id = s;
			}
			else if (m_inLogo)
			{
				m_currentFeed.logo = s;
			}
			else if (m_inSubtitle)
			{
				m_currentFeed.subtitle = s;
			}
			else if (m_inTitle)
			{
				m_currentFeed.title = s;
			}
			if (m_inUpdated)
			{
				m_currentFeed.updated = s;
			}
		}
	}

	void startDocument()
	{
	}

	void endDocument()
	{
		// create a FeedInfo object from the parsed feed
		auto entries = m_currentFeed.entries.data();
        auto articles = appender!(Article[])();

		// Fill the articles array from entries 
		foreach (i, entry; entries)
		{
			// Get Article title
			string title = entry.title;
			try 
			{
				title = xml.parser.Parser.translateEntities(title);
			}
			catch (SAXParseException)
			{
			}
		
			// Get article author
			string author = entry.authors.data().map!(auth => auth.name).join(", ");
			try 
			{
				author = xml.parser.Parser.translateEntities(author);
			}
			catch (SAXParseException)
			{
			}

			// Get article summary
			string description = entry.summary;
			try 
			{
				description = xml.parser.Parser.translateEntities(description);
			}
			catch (SAXParseException)
			{
			}

			auto foundLink = find!(l => l.rel == "alternate")(entry.links.data());
			if (foundLink.empty)
			{
				continue;
			}
			string url = foundLink.front.href;

			// Get article time
			time_t t = SysTime.fromISOExtString(entry.updated).toUnixTime();

			articles.put(new Article(title, author, take(description, 500), url, t));
		}

		// create the Feed object
		string name = m_currentFeed.title;
		string url = m_owner.m_originURL;
		string link = m_currentFeed.links.data().empty ? "" : m_currentFeed.links.data()[0].href;
		

		auto fi = new shared(FeedInfo)(name, url, link, articles.data());
		fi.setIcon(m_currentFeed.icon);
		m_owner.setFeedInfo(fi);
	}

	void startElement(string uri, string localName, string qName,
					  const ref Attributes atts)
	{
		if (localName == "title")
		{
			m_inTitle = true;
		}
		else if (localName == "author")
		{
			m_inAuthor = true;
		}
		else if (localName == "entry")
		{
			m_inEntry = true;
		}
		else if (localName == "link")
		{
			AtomLink lnk;
			auto index = atts.getIndex("href");
			if (index != -1)
			{
				lnk.href = atts.getValue(index);
			}

			index = atts.getIndex("rel");
			if (index != -1)
			{
				lnk.rel = atts.getValue(index);
			}

			index = atts.getIndex("type");
			if (index != -1)
			{
				lnk.type = atts.getValue(index);
			}

			index = atts.getIndex("hreflang");
			if (index != -1)
			{
				lnk.hreflang = atts.getValue(index);
			}

			index = atts.getIndex("title");
			if (index != -1)
			{
				lnk.title = atts.getValue(index);
			}

			index = atts.getIndex("length");
			if (index != -1)
			{
				try
				{
					lnk.length = to!(size_t)(atts.getValue(index));
				}
				catch(ConvException)
				{
					// Prevent error propagation
				}
			}

			if (m_inEntry)
			{
				m_currentEntry.links.put(lnk);
			}
			else
			{
				m_currentFeed.links.put(lnk);
			}
		}
		else if (localName == "name")
		{
			m_inName = true;
		}
		else if (localName == "uri")
		{
			m_inUri = true;
		}
		else if (localName == "email")
		{
			m_inEmail = true;
		}
		else if (localName == "category")
		{
			AtomCategory cat;

			auto index = atts.getIndex("term");
			if (index != -1)
			{
				cat.term = atts.getValue(index);
			}

			index = atts.getIndex("label");
			if (index != -1)
			{
				cat.label = atts.getValue(index);
			}

			if (m_inEntry)
			{
				m_currentEntry.categories.put(cat);
			}
			else
			{
				m_currentFeed.categories ~= cat;
			}
		}
		else if (localName == "id")
		{
			m_inId = true;
		}
		else if (localName == "published")
		{
			m_inPublished = true;
		}
		else if (localName == "updated")
		{
			m_inUpdated = true;
		}
		else if (localName == "rights")
		{
			m_inRights = true;
		}
		else if (localName == "summary")
		{
			m_inSummary = true;
		}
		else if (localName == "icon")
		{
			m_inIcon = true;
		}
		else if (localName == "logo")
		{
			m_inLogo = true;
		}
		else if (localName == "subtitle")
		{
			m_inSubtitle = true;
		}
	}

	void endElement(string uri, string localName, string qName)
	{
		if (localName == "title")
		{
			m_inTitle = false;
		}
		else if (localName == "author")
		{
			if (m_inEntry)
			{
				m_currentEntry.authors.put(m_currentPerson);
			}
			else
			{
				m_currentFeed.authors.put(m_currentPerson);
			}
			m_currentPerson = AtomPerson.init;
			m_inAuthor = false;
		}
		else if (localName == "contributor")
		{
			if (m_inEntry)
			{
				m_currentEntry.contributors.put(m_currentPerson);
			}
			else
			{
				m_currentFeed.contributors.put(m_currentPerson);
			}
			m_currentPerson = AtomPerson.init;
			m_inAuthor = false;
		}
		else if (localName == "entry")
		{
			m_currentFeed.entries.put(m_currentEntry);
			m_currentEntry = AtomEntry.init;
			m_inEntry = false;
		}
		else if (localName == "name")
		{
			m_inName = false;
		}
		else if (localName == "uri")
		{
			m_inUri = false;
		}
		else if (localName == "email")
		{
			m_inEmail = false;
		}
		else if (localName == "id")
		{
			m_inId = false;
		}
		else if (localName == "published")
		{
			m_inPublished = false;
		}
		else if (localName == "updated")
		{
			m_inUpdated = false;
		}
		else if (localName == "rights")
		{
			m_inRights = false;
		}
		else if (localName == "summary")
		{
			m_inSummary = false;
		}
		else if (localName == "icon")
		{
			m_inIcon = false;
		}
		else if (localName == "logo")
		{
			m_inLogo = false;
		}
		else if (localName == "subtitle")
		{
			m_inSubtitle = false;
		}
	}

	void processingInstruction(string target, string data)
	{
	}
}

/**
 * Strategy pattern for parsing RSS 2.0 document.
 */
final class RSS20Strategy : FeedStrategy
{
	// all these flags indicate we are in an open tag 

	bool    m_inItem;
	bool	m_inTitle;
	bool    m_inLink;
	bool    m_inDescription;
	bool    m_inLanguage;
	bool    m_inCopyright;
	bool    m_inManagingEditor;
	bool    m_inWebMaster;
	bool    m_inPubDate;
	bool    m_inLastBuildDate;
	bool    m_inCategory;
	bool    m_inGenerator;
	bool    m_inTtl;
	bool    m_inAuthor;
	bool    m_inComments;
	bool    m_inGuid;
	bool    m_inDcDate;

	static struct RSSItem
	{
		string title;
		string link;
		string description;
		string author;
		string category;
		string comments;
		string guid;
		time_t pubDate;
		string source;
		string image;
	}

	static struct RSSFeed
	{
		string title;
		string link;
		string description;
		string language;
		string copyright;
		string managingEditor;
		string webMaster;
		time_t pubDate;
		time_t lastBuildDate;
		string category;
		string generator;
		string ttl;
		Appender!(RSSItem[]) items;
	}

	RSSFeed m_currentFeed;
	RSSItem m_currentItem;

public:
	this(FeedContentHandler owner)
	{
		super(owner);
	}

	void startDocument()
	{
		m_inItem = m_inTitle = m_inLink = false;
	}

	void endDocument()
	{
		// publish the parsed feed as a FeedInfo object.
		auto items = m_currentFeed.items.data();
		//auto articles = uninitializedArray!(FeedArticle[])(items.length);
        auto articles = appender!(Article[])();
		foreach (i, item; items)
		{
			// links can contain & characters for GET parameter
			// list (although incorrect from XML point of view)
			string link = item.link;
			try
			{
				link = xml.parser.Parser.translateEntities(link);
			}
			catch(SAXParseException)
			{
			}

			// if description contains HTML entities, translate them into UTF8
			auto desc = item.description;
			try 
			{
				desc = xml.parser.Parser.translateEntities(desc);
			}
			catch (SAXParseException)
			{
			}

			auto title = item.title;
			try
			{
				title = xml.parser.Parser.translateEntities(title);
			}
			catch (SAXParseException)
			{
			}

			auto auth = item.author;
			try
			{
				auth = xml.parser.Parser.translateEntities(auth);
			}
			catch (SAXParseException)
			{
			}

			articles.put(new Article(title, 
										  auth,
										  take(desc, 500),
										  link,
										  item.pubDate));
		}
		auto feedInfo = new shared FeedInfo(xml.parser.Parser.translateEntities(m_currentFeed.title),  
											m_owner.m_originURL, m_currentFeed.link, 
											articles.data());
		m_owner.setFeedInfo(feedInfo);
	}

	void startElement(string uri, string localName, string qName, ref const(Attributes) atts)
	{
		if (qName == "item")
		{
			m_inItem = true;
		}
		else if (qName == "title")
		{
			m_inTitle = true;
		}
		else if (qName == "link")
		{
			m_inLink = true;
		}
		else if (qName == "description")
		{
			m_inDescription = true;
		}
		else if (qName == "language")
		{
			m_inLanguage = true;
		}
		else if (qName == "copyright")
		{
			m_inCopyright = true;
		}
		else if (qName == "managingEditor")
		{
			m_inManagingEditor = true;
		}
		else if (qName == "webMaster")
		{
			m_inWebMaster = true;
		}
		else if (qName == "pubDate")
		{
			m_inPubDate = true;
		}
		else if (qName == "lastBuildDate")
		{
			m_inLastBuildDate = true;
		}
		else if (qName == "category")
		{
			m_inCategory = true;
		}
		else if (qName == "generator")
		{
			m_inGenerator = true;
		}
		else if (qName == "ttl")
		{
			m_inTtl = true;
		}
		else if (qName == "author")
		{
			m_inAuthor = true;
		}
		else if (qName == "guid")
		{
			m_inGuid = true;
		}
		else if (qName == "comments")
		{
			m_inComments = true;
		}
		else if (qName == "dc:date")
		{
			m_inDcDate = true;
		}
	}

	void endElement(string uri, string localName, string qName)
	{
		if (qName == "item")
		{
			m_currentFeed.items.put(m_currentItem);
			m_currentItem = RSSItem.init;
			m_inItem = false;
		}
		else if (qName == "title")
		{
			m_inTitle = false;
		}
		else if (qName == "link")
		{
			m_inLink = false;
		}
		else if (qName == "description")
		{
			m_inDescription = false;
		}
		else if (qName == "language")
		{
			m_inLanguage = false;
		}
		else if (qName == "copyright")
		{
			m_inCopyright = false;
		}
		else if (qName == "managingEditor")
		{
			m_inManagingEditor = false;
		}
		else if (qName == "webMaster")
		{
			m_inWebMaster = false;
		}
		else if (qName == "pubDate")
		{
			m_inPubDate = false;
		}
		else if (qName == "lastBuildDate")
		{
			m_inLastBuildDate = false;
		}
		else if (qName == "category")
		{
			m_inCategory = false;
		}
		else if (qName == "generator")
		{
			m_inGenerator = false;
		}
		else if (qName == "ttl")
		{
			m_inTtl = false;
		}
		else if (qName == "author")
		{
			m_inAuthor = false;
		}
		else if (qName == "guid")
		{
			m_inGuid = false;
		}
		else if (qName == "comments")
		{
			m_inComments = false;
		}
		else if (qName == "dc:date")
		{
			m_inDcDate = false;
		}
	}

	void characters(string s)
	{
		if (!m_inItem)
		{
			if (m_inTitle)
			{
				m_currentFeed.title = s;
			}
			else if (m_inLink)
			{
				m_currentFeed.link = s;
			}
			else if (m_inDescription)
			{
				m_currentFeed.description = s;
			}
			else if (m_inLanguage)
			{
				m_currentFeed.language = s;
			}
			else if (m_inCopyright)
			{
				m_currentFeed.copyright = s;
			}
			else if (m_inManagingEditor)
			{
				m_currentFeed.managingEditor = s;
			}
			else if (m_inWebMaster)
			{
				m_currentFeed.webMaster = s;
			}
			else if (m_inPubDate)
			{
				if (!s.empty)
				{
					m_currentFeed.pubDate = convertDate(s).toUnixTime();
				}
			}
			else if (m_inLastBuildDate)
			{
				if (!s.empty)
				{
					m_currentFeed.lastBuildDate = convertDate(s).toUnixTime();
				}
			}
			else if (m_inDcDate)
			{
				if (!s.empty)
				{
					m_currentFeed.lastBuildDate = m_currentFeed.pubDate = SysTime.fromISOExtString(s).toUnixTime();
				}
			}
			else if (m_inCategory)
			{
				m_currentFeed.category = s;
			}
			else if (m_inGenerator)
			{
				m_currentFeed.generator = s;
			}
			else if (m_inTtl)
			{
				m_currentFeed.ttl = s;
			}
		}
		else
		{
			if (m_inTitle)
			{
				m_currentItem.title = s;
			}
			else if (m_inLink)
			{
				m_currentItem.link = s;
			}
			else if (m_inDescription)
			{
				m_currentItem.description = s;
			}
			else if (m_inAuthor)
			{
				m_currentItem.author = s;
			}
			else if (m_inCategory)
			{
				m_currentItem.category = s;
			}
			else if (m_inComments)
			{
				m_currentItem.comments = s;
			}
			else if (m_inGuid)
			{
				m_currentItem.guid = s;
			}
			else if (m_inPubDate)
			{
				if (!s.empty)
				{
					m_currentItem.pubDate = convertDate(s).toUnixTime();
				}
			}
			else if (m_inDcDate)
			{
				if (!s.empty)
				{
					m_currentItem.pubDate = SysTime.fromISOExtString(s).toUnixTime();
				}
			}
		}
	}

	void processingInstruction(string target, string data)
	{
	}
}

/**
 * Strategy pattern for parsing RSS 1.0 document.
 */
final class RSS10Strategy : FeedStrategy
{
	bool m_inChannel;
	bool m_inTitle;
	bool m_inLink;
	bool m_inDescription;
	bool m_inItems;
	bool m_inItem;
	bool m_inDcDate;
	bool m_inDcCreator;

	struct RSS10Item
	{
		string title;
		string link;
		string creator;
		string description;
		time_t updated;
	}

	struct RSS10Channel
	{
		string title;
		string link;
		string description;
		string image;
		Appender!(RSS10Item[]) items;
	}

	RSS10Item    m_currentItem;
	RSS10Channel m_currentChannel;


public:
	this(FeedContentHandler owner)
	{
		super(owner);
	}

	void startDocument()
	{
		// Nothing to do
	}

	void endDocument()
	{
		// publish the parsed feed as a FeedInfo object.
		auto items = m_currentChannel.items.data();
		//auto articles = uninitializedArray!(FeedArticle[])(items.length);
        auto articles = appender!(Article[])();
		foreach (i, item; items)
		{
			// links can contain & characters for GET parameter
			// list (although incorrect from XML point of view)
			string link = item.link;
			try
			{
				link = xml.parser.Parser.translateEntities(link);
			}
			catch(SAXParseException)
			{
			}

			// if description contains HTML entities, translate them into UTF8
			auto desc = item.description;
			try 
			{
				desc = xml.parser.Parser.translateEntities(desc);
			}
			catch (SAXParseException)
			{
			}

			auto title = item.title;
			try
			{
				title = xml.parser.Parser.translateEntities(title);
			}
			catch (SAXParseException)
			{
			}

			auto creator = item.creator;
			try
			{
				creator = xml.parser.Parser.translateEntities(creator);
			}
			catch (SAXParseException)
			{
			}

			articles.put(new Article(title, 
										  creator,
										  take(desc, 500),
										  link,
										  item.updated));
		}
		auto feedInfo = new shared FeedInfo(xml.parser.Parser.translateEntities(m_currentChannel.title),  
											m_owner.m_originURL, m_currentChannel.link, 
											articles.data());
		m_owner.setFeedInfo(feedInfo);
	}

	void startElement(string uri, string localName, string qName, const ref Attributes atts)
	{
		if (localName == "channel")
		{
			m_inChannel = true;
		}
		else if (localName == "title")
		{
			m_inTitle = true;
		}
		else if (localName == "description")
		{
			m_inDescription = true;
		}
		else if (localName == "image")
		{
			auto index = atts.getIndex("rdf:resource");
			if (index != -1)
			{
				m_currentChannel.image = atts.getValue(index);
			}
		}
		else if (localName == "item")
		{
			m_inItem = true;
		}
		else if (qName == "dc:date")
		{
			m_inDcDate = true;
		}
		else if (qName == "dc:creator")
		{
			m_inDcCreator = true;
		}
	}

	void characters(string s)
	{
		if (m_inChannel)
		{
			if (m_inTitle)
			{
				m_currentChannel.title = s;
			}
			else if (m_inLink)
			{
				m_currentChannel.link = s;
			}
			else if (m_inDescription)
			{
				m_currentChannel.description = s;
			}
		}
		else if (m_inItem)
		{
			if (m_inTitle)
			{
				m_currentItem.title = s;
			}
			else if (m_inLink)
			{
				m_currentItem.link = s;
			}
			else if (m_inDescription)
			{
				m_currentItem.description = s;
			}
			else if (m_inDcDate)
			{
				m_currentItem.updated = SysTime.fromISOExtString(s).toUnixTime();
			}
			else if (m_inDcCreator)
			{
				m_currentItem.creator = s;
			}
		}
	}

	void endElement(string uri, string localName, string qName)
	{
		if (localName == "channel")
		{
			m_inChannel = false;
		}
		else if (localName == "title")
		{
			m_inTitle = false;
		}
		else if (localName == "description")
		{
			m_inDescription = false;
		}
		else if (localName == "item")
		{
			m_currentChannel.items.put(m_currentItem);
			m_currentItem = RSS10Item.init;
			m_inItem = false;
		}
		else if (qName == "dc:date")
		{
			m_inDcDate = false;
		}
		else if (qName == "dc:creator")
		{
			m_inDcCreator = false;
		}
	}

	void processingInstruction(string target, string data)
	{
	}
}


final class FeedContentHandler : ContentHandler
{
private:
	FeedStrategy m_strategy;
	shared FeedInfo     m_feedInfo;
	string m_originURL;

	void setStrategy(FeedStrategy strat)
	{
		m_strategy = strat;
	}

	void setFeedInfo(shared FeedInfo fi)
	{
		m_feedInfo = fi;
	}

public:
	this(string originURL)
	{
		m_strategy = new StartStrategy(this);
		m_originURL = originURL;
	}

	// redirect any parsing to the strategy

	shared(FeedInfo) getFeedInfo()
	{
		return m_feedInfo;
	}

	void startDocument()
	{
		m_strategy.startDocument();
	}

	void endDocument()
	{
		m_strategy.endDocument();
	}

	void characters(string ch)
	{
		m_strategy.characters(ch);
	}

	void startElement(string uri, string localName, string qName, ref const(Attributes) atts)
	{
		m_strategy.startElement(uri, localName, qName, atts);
	}

	void endElement(string uri, string localName, string qName)
	{
		m_strategy.endElement(uri, localName, qName);
	}

	void processingInstruction(string target, string data)
	{
		m_strategy.processingInstruction(target, data);
	}
}