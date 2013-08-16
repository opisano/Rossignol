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

module gui.articletable;

import std.algorithm;
import std.array;
import std.conv;
import std.string;
import std.typecons;
import std.c.time;

import org.eclipse.swt.SWT;
import org.eclipse.swt.events.MouseAdapter;
import org.eclipse.swt.events.MouseEvent;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Table;
import org.eclipse.swt.widgets.TableColumn;
import org.eclipse.swt.widgets.TableItem;

import feed;
import gui.mainwindow;
import properties;

private enum SortMode
{
	title,
	author,
	time
}

private enum SortOrder
{
	ascending,
	descending
}

/**
 * Compare two articles by their title
 */
bool compByTitle(SortOrder order = SortOrder.ascending)(Article a, Article b) pure
{
	static if (order == SortOrder.ascending)
	{
		return icmp(a.getTitle(), b.getTitle()) < 0;
	}
	else
	{
		return icmp(a.getTitle(), b.getTitle()) > 0;
	}
}

/**
 * Compare two articles by their author
 */
bool compByAuthor(SortOrder order = SortOrder.ascending)(Article a, Article b) pure
{
	static if (order == SortOrder.ascending)
	{
		return icmp(a.getAuthor(), b.getAuthor()) < 0;
	}
	else
	{
		return icmp(a.getAuthor(), b.getAuthor()) > 0;
	}
}

/**
 * Compare two articles by their date
 */
bool compByTime(SortOrder order = SortOrder.ascending)(Article a, Article b) pure
{
	static if (order == SortOrder.ascending)
	{
		return a.getTime() < b.getTime();
	}
	else 
	{
		return a.getTime() > b.getTime();
	}
}


private void displayURL(string url)
{
	version (Windows)
	{
		import std.c.windows.windows;

		ShellExecuteA(null, "open".ptr, toStringz(url), null, null, 0);
	}
}

private SortOrder switchOrder(SortOrder order)
{
	return order == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
}

final class ArticleTable : AdjustableComponent
{
	Table					m_tblArticles;
	MainWindow				m_mainWindow;
	shared FeedInfo			m_feedInfo;
	Rebindable!Article[]    m_articles;
	TableColumn             m_colTitle;
	TableColumn             m_colAuthor;
	TableColumn             m_colDate;
	SortMode                m_sortMode;
	SortOrder               m_sortOrder;
	TableColumn             m_lastColumn;

	class CallbackListener : Listener
	{
	public:
		override void handleEvent(Event event)
		{
			TableItem item = cast(TableItem)event.item;
			int tableIndex = m_tblArticles.indexOf(item);
			auto article = m_articles[tableIndex];
			
			item.setText(0, article.getTitle());
			item.setText(1, article.getAuthor());
			{
				auto t = article.getTime();
				const tm* utcTime = gmtime(&t);
				char[50] buffer;
				auto size = strftime(buffer.ptr, buffer.length, "%d/%m/%Y %T", utcTime);
				item.setText(2, to!string(buffer[0..size])); 
			}
			item.setData(cast(FeedArticle)article);
		}
	}

	class SortListener : Listener
	{
	public:
		override void handleEvent(Event event)
		{
			TableColumn col = cast(TableColumn)event.widget;
			if (col is m_lastColumn)
			{
				m_sortOrder = switchOrder(m_sortOrder);
				sortTable(m_sortMode);
			}
			else if (col is m_colTitle)
			{
				sortTable(SortMode.title);
			}
			else if (col is m_colAuthor)
			{
				sortTable(SortMode.author);
			}
			else if (col is m_colDate)
			{
				sortTable(SortMode.time);
			}
			m_lastColumn = col;
			m_tblArticles.clearAll();
		}
	}

	void sortTable(SortMode mode)
	{
		final switch (mode)
		{
		case SortMode.title:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByTitle)(m_articles);
			else
				sort!(compByTitle!(SortOrder.descending))(m_articles);
			break;
		case SortMode.author:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByAuthor)(m_articles);
			else
				sort!(compByAuthor!(SortOrder.descending))(m_articles);
			break;
		case SortMode.time:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByTime)(m_articles);
			else
				sort!(compByTime!(SortOrder.descending))(m_articles);
			break;
		}
		m_sortMode = mode;
	}

public:
	this(MainWindow mainWindow, Composite parent, int style)
	{
		m_mainWindow = mainWindow;
		m_tblArticles = new Table(parent, SWT.MULTI | SWT.FULL_SELECTION| SWT.BORDER | SWT.VIRTUAL);
		m_sortMode = SortMode.time;
		m_sortOrder = SortOrder.descending;
		
		m_colTitle = new TableColumn(m_tblArticles, SWT.NONE);
		m_colTitle.setText("Title");
		m_colTitle.setWidth(280);
		m_colAuthor = new TableColumn(m_tblArticles, SWT.NONE);
		m_colAuthor.setText("Author");
		m_colDate = new TableColumn(m_tblArticles, SWT.NONE);
		m_colDate.setText("Date");
		m_tblArticles.setHeaderVisible(true);
		m_tblArticles.setLinesVisible(true);

		m_tblArticles.addMouseListener(new class MouseAdapter
			{
				override public void mouseDoubleClick(MouseEvent e)
				{
					auto pt = new Point(e.x, e.y);
					auto item = m_tblArticles.getItem(pt);
					if (item is null)
					{
						return;
					}
					displayArticleInBrowser(item);
				}
			});

		auto sortListener = new SortListener;
		m_colTitle.addListener(SWT.Selection, sortListener);
		m_colAuthor.addListener(SWT.Selection, sortListener);
		m_colDate.addListener(SWT.Selection, sortListener);
		m_tblArticles.addListener(SWT.SetData, new CallbackListener);

		m_colAuthor.pack();
		m_colDate.pack();
		m_tblArticles.pack();
	}

	void setFeedInfo(shared FeedInfo feedInfo)
	{
		if (feedInfo !is m_feedInfo)
		{
			m_feedInfo = feedInfo;
			auto count = m_feedInfo.getArticles().length;
			m_articles = new Rebindable!Article[count];
			foreach (index, article; m_feedInfo.getArticles())
			{
				m_articles[index] = article;
			}
			sortTable(m_sortMode);

			m_tblArticles.setItemCount(count);
			m_tblArticles.clear(0, count-1);
		}
	}

	void refresh()
	{
		auto count = m_feedInfo.getArticles().length;
		m_articles = new Rebindable!Article[count];
		foreach (index, article; m_feedInfo.getArticles())
		{
			m_articles[index] = article;
		}
		sortTable(m_sortMode);

		m_tblArticles.setItemCount(count);
		m_tblArticles.clear(0, count-1);
	}

	shared(FeedInfo) getDisplayedFeed()
	{
		return m_feedInfo;
	}

	void displayArticleInBrowser(TableItem item)
	{
		if (item is null)
		{
			return;
		}

		auto article = cast(FeedArticle) item.getData();

		if (article is null)
		{
			return;
		}

		string url = article.getURL();
		displayURL(url);
	}


	Properties getProperties()
	{
		Properties props;
		props["ARTICLE_TABLE_COL_TITLE_WIDTH"] = to!string(m_colTitle.getWidth());
		props["ARTICLE_TABLE_COL_AUTHOR_WIDTH"] = to!string(m_colAuthor.getWidth());
		props["ARTICLE_TABLE_COL_DATE_WIDTH"] = to!string(m_colDate.getWidth());

		return props;
	}

	void setProperties(Properties props)
	{
		int width = to!int(props.get("ARTICLE_TABLE_COL_TITLE_WIDTH", "280"));
		m_colTitle.setWidth(width);

		width = to!int(props.get("ARTICLE_TABLE_COL_AUTHOR_WIDTH", "100"));
		m_colAuthor.setWidth(width);

		width = to!int(props.get("ARTICLE_TABLE_COL_DATE_WIDTH", "100"));
		m_colAuthor.setWidth(width);
	}

	alias m_tblArticles this;
}