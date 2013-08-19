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
import std.concurrency;
import std.container;
import std.conv;
import std.datetime;
import std.exception;
import std.file;
import std.net.curl;
import std.parallelism;
import std.regex;
import std.string;

import std.c.time;

import org.eclipse.swt.graphics.Image;

import date;
import xml.attributes;
import xml.handler;

/**
 * Modelizes an article in a Feed
 */
final class FeedArticle
{
	string  m_title;

	string  m_author;

	string  m_url;

	time_t m_time;

public:
	this(string title, string author, string url, time_t time)
	{
		m_title		= title;
		m_author	= author;
		m_url		= url;
		m_time      = time;
	}

	this(string title, string author, string url, time_t time) immutable
	{
		m_title		= title;
		m_author	= author;
		m_url		= url;
		m_time      = time;
	}

	string getTitle() const pure nothrow
	{
		return m_title;
	}

	string getAuthor() const pure nothrow
	{
		return m_author;
	}

	string getURL() const pure nothrow
	{
		return m_url;
	}

	time_t getTime() const pure nothrow
	{
		return m_time;
	}

	string toXML() const
	{
		return format("<article title=\"%s\" author=\"%s\" url=\"%s\" time=\"%s\"/>",
					  xml.parser.Parser.encodeEntities(m_title), xml.parser.Parser.encodeEntities(m_author), m_url, m_time);
	}
}

alias immutable(FeedArticle) Article;

/**
 * Interface to implement in order to react to a change in a FeedInfo object.
 */
interface FeedInfoListener
{
	/**
	 * Signals articles have been added to a feed
	 */
	void articlesAdded(shared(FeedInfo) src, size_t count);
}

/**
 * Modelizes a Feed
 */
final synchronized class FeedInfo
{
	string		m_name;

	string		m_link;

	string      m_url;

	Article[]	m_articles;

	string      m_icon;

	// cached for performance reasons
	time_t      m_mostRecentArticle; 

	FeedInfoListener[FeedInfoListener] m_listeners;

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

	size_t add(Article[] articles)
	{
		// get our most recent article time
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
			foreach (a; newArticles)
			{
				m_articles ~= a;
				added++;
			}

			// update our most recent article time
			m_mostRecentArticle = newArticles.map!((a) => a.getTime())
											 .reduce!max;
		}
		return added;
	}

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
				time_t t = to!time_t(atts.getValue("time"));

				result.back.appendArticle(new Article(title, author, url, t));
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


abstract class FeedStrategy : ContentHandler
{
protected:
	FeedContentHandler m_owner;
public:
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
		auto articles = uninitializedArray!(FeedArticle[])(entries.length);

		// Fill the articles array from entries 
		foreach (i, entry; entries)
		{
			// Get Article title
			string title = entry.title;
		
			// Get article author
			string author = entry.authors.data().map!(auth => auth.name).join(" & ");

			auto foundLink = find!(l => l.rel == "alternate")(entry.links.data());
			if (foundLink.empty)
			{
				continue;
			}
			string url = foundLink.front.href;

			// Get article time
			time_t t = SysTime.fromISOExtString(entry.updated).toUnixTime();

			articles[i] = new FeedArticle(title, author, url, t);
		}

		// create the Feed object
		string name = m_currentFeed.title;
		string url = m_owner.m_originURL;
		string link = m_currentFeed.links.data().empty ? "" : m_currentFeed.links.data()[0].href;
		

		auto fi = new shared(FeedInfo)(name, url, link, assumeUnique(articles));
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
		auto articles = uninitializedArray!(FeedArticle[])(items.length);
		foreach (i, item; items)
		{
			articles[i] = new FeedArticle(xml.parser.Parser.translateEntities(item.title), 
										  xml.parser.Parser.translateEntities(item.author), 
										  xml.parser.Parser.translateEntities(item.link),
										  item.pubDate);
		}
		auto feedInfo = new shared FeedInfo(xml.parser.Parser.translateEntities(m_currentFeed.title),  
											m_owner.m_originURL, m_currentFeed.link, 
											assumeUnique(articles));
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