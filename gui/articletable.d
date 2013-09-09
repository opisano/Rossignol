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
import org.eclipse.swt.events.SelectionAdapter;
import org.eclipse.swt.events.SelectionEvent;
import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.layout.FillLayout;
import org.eclipse.swt.widgets.Composite;
import org.eclipse.swt.widgets.Event;
import org.eclipse.swt.widgets.Label;
import org.eclipse.swt.widgets.Listener;
import org.eclipse.swt.widgets.Menu;
import org.eclipse.swt.widgets.MenuItem;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.swt.widgets.Table;
import org.eclipse.swt.widgets.TableColumn;
import org.eclipse.swt.widgets.TableItem;

import feed;
import gui.mainwindow;
import html.html;
import properties;



/*----------------------------------------------------------------------------*
 *                                                                            *
 *    Sorting facilities                                                      *
 *                                                                            *
 *                                                                            *
 *----------------------------------------------------------------------------*/


/**
 * Sort mode (each by table column)
 */
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

/**
 * OS-dependant facility to open an URL by the user default 
 * browser.
 */
private void displayURL(string url)
{
	version (Windows)
	{
		import std.c.windows.windows;

		ShellExecuteA(null, "open".ptr, toStringz(url), null, null, 0);
	}
    version (linux)
    {
         std.c.stdlib.system(toStringz("xdg-open " ~ url));
    }

}

/**
 * Switch sort order.
 */
private SortOrder switchOrder(SortOrder order)
{
	return order == SortOrder.ascending ? SortOrder.descending : SortOrder.ascending;
}

/**
 * Provides a way of displaying a list of articles, sorting them.
 */
final class ArticleTable : AdjustableComponent
{
	// The actual SWT widget.
	Table					m_tblArticles;
	// reference to the application main window
	MainWindow				m_mainWindow;
	// the feed from which we display the articles
	shared FeedInfo			m_feedInfo;
	// a copy of the feed articles, for sorting
	Rebindable!Article[]    m_articles;
	// table columns
	TableColumn             m_colTitle;
	TableColumn             m_colAuthor;
	TableColumn             m_colDate;
	SortMode                m_sortMode;
	SortOrder               m_sortOrder;
	// last column clicked
	TableColumn             m_lastColumn;

    // Right click menu
    Menu                    m_popupMenu;

	/**
	 * Provides a callback for displaying an item 
	 */
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
				if (t != time_t.init)
				{
					const tm* utcTime = gmtime(&t);
					char[50] buffer;
					auto size = strftime(buffer.ptr, buffer.length, "%d/%m/%Y %T", utcTime);
					item.setText(2, to!string(buffer[0..size]));
				}
			}
			item.setData(cast(FeedArticle)article);

            // if the article has an enclosure, display the icon
            if (!article.getEnclosure().strip().empty)
            {
                item.setImage(m_mainWindow.getResourceManager().getImage("attachment"));
            }
		}
	}

	/**
	 * Responds to a click on a column header to change the sorting mode.
	 */
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

	/**
	 * Sorts the table (yes, you could have figure it out).
	 */
	void sortTable(SortMode mode)
	{
		final switch (mode)
		{
		case SortMode.title:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByTitle, SwapStrategy.stable)(m_articles);
			else
				sort!(compByTitle!(SortOrder.descending), SwapStrategy.stable)(m_articles);
			break;
		case SortMode.author:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByAuthor, SwapStrategy.stable)(m_articles);
			else
				sort!(compByAuthor!(SortOrder.descending), SwapStrategy.stable)(m_articles);
			break;
		case SortMode.time:
			if (m_sortOrder == SortOrder.ascending)
				sort!(compByTime, SwapStrategy.stable)(m_articles);
			else
				sort!(compByTime!(SortOrder.descending), SwapStrategy.stable)(m_articles);
			break;
		}
		m_sortMode = mode;
	}

	/**
	 * Implement a fake tooltip
	 */
	class LabelListener : Listener
	{
	public:
		override void handleEvent(Event event)
		{
			Label label = cast (Label) event.widget;
			Shell shell = label.getShell();
			final switch (event.type)
			{
			case SWT.MouseDown:
				Event e = new Event;
				e.item = cast(TableItem) label.getData("_TABLEITEM");
				m_tblArticles.setSelection([cast(TableItem)e.item]);
				m_tblArticles.notifyListeners(SWT.Selection, e);
				goto case SWT.MouseExit; // fall through

			case SWT.MouseExit:
				shell.dispose();
				break;
			}
		}
	}

	class TableListener : Listener
	{
		Shell tip;
		Label label;
		LabelListener m_labelListener;

	public:

		this(LabelListener labelListener)
		{
			m_labelListener = labelListener;
		}

		override void handleEvent(Event event)
		{
			final switch (event.type)
			{
			case SWT.Dispose:
			case SWT.KeyDown:
			case SWT.MouseMove:
				if (tip is null)
				{
					break;
				}
				tip.dispose();
				tip = null;
				label = null;
				break;

			case SWT.MouseHover:
				TableItem item = m_tblArticles.getItem(new Point(event.x, event.y));
				if (item !is null)
				{
					if (tip !is null && !tip.isDisposed())
					{
						tip.dispose();
					}
                    Article art = cast(Article)item.getData();
                    string content = art.getDescription().htmlToText().wrap(80);
                    try
                    {
                        content = xml.parser.Parser.translateEntities(content);
                    }
                    catch (Exception)
                    {
                    }

                    if (!strip(content).empty)
                    {
					    tip = new Shell(m_mainWindow.m_shell, SWT.ON_TOP | SWT.TOOL);
					    tip.setLayout(new FillLayout);
					    label = new Label(tip, SWT.NONE);
					    auto disp = m_mainWindow.m_shell.getDisplay();
					    label.setForeground(disp.getSystemColor(SWT.COLOR_INFO_FOREGROUND));
					    label.setBackground(disp.getSystemColor(SWT.COLOR_INFO_BACKGROUND));
					    label.setData("_TABLEITEM", item);
					    
					    label.setText(content);
					    label.addListener(SWT.MouseExit, m_labelListener);
					    label.addListener(SWT.MouseDown, m_labelListener);
					    Point size = tip.computeSize(SWT.DEFAULT, SWT.DEFAULT);
					    Rectangle rect = item.getBounds(0);
					    Point pt = m_tblArticles.toDisplay(event.x, event.y);
					    tip.setBounds(pt.x, pt.y, size.x, size.y);
					    tip.setVisible(true);
                    }
				}
			}
		}
	}

    void populatePopupMenu(Article article)
    {
        // Clear menu
        foreach (item; m_popupMenu.getItems())
        {
            item.dispose();
        }

        if (article is null)
        {
            return;
        }

        MenuItem mnuOpenURL = new MenuItem(m_popupMenu, 0);
        mnuOpenURL.setText("Open article URL");
        mnuOpenURL.addSelectionListener(
            new class SelectionAdapter
            {
                override public void widgetSelected(SelectionEvent e)
                {
                    displayURL(article.getURL());
                }
            });

        if (!article.getEnclosure().strip().empty)
        {
            MenuItem mnuEnclosure = new MenuItem(m_popupMenu, 0);
            mnuEnclosure.setText("Open attachment");
            mnuEnclosure.addSelectionListener(
                new class SelectionAdapter
                {
                    override public void widgetSelected(SelectionEvent e)
                    {
                        displayURL(article.getEnclosure().strip());
                    }
                });
        }
    }

public:
	/**
	 * Creates an article table
	 */
	this(MainWindow mainWindow, Composite parent, int style)
	{
		m_mainWindow = mainWindow;
		// create the SWT widget
		m_tblArticles = new Table(parent, SWT.MULTI | SWT.FULL_SELECTION| SWT.BORDER | SWT.VIRTUAL);
        m_popupMenu = new Menu(m_tblArticles);
		m_sortMode = SortMode.time;
		m_sortOrder = SortOrder.descending;
		
		// create the table columns
		m_colTitle = new TableColumn(m_tblArticles, SWT.NONE);
        m_colTitle.setText(mainWindow.getResourceManager().getText("TABLE_TITLE_COLUMN"));
		m_colTitle.setWidth(280);
		m_colAuthor = new TableColumn(m_tblArticles, SWT.NONE);
        m_colAuthor.setText(mainWindow.getResourceManager().getText("TABLE_AUTHOR_COLUMN"));
		m_colDate = new TableColumn(m_tblArticles, SWT.NONE);
        m_colDate.setText(mainWindow.getResourceManager().getText("TABLE_DATE_COLUMN"));
		m_tblArticles.setHeaderVisible(true);
		m_tblArticles.setLinesVisible(true);

		// On double click on a line, display the article in the user browser.
		m_tblArticles.addMouseListener(
			new class MouseAdapter
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

                override public void mouseUp(MouseEvent e)
                {
                    if (e.button == 3)
                    {
                        // get TreeItem at position (e.x, e.y) and select it
						Point relativePt = new Point(e.x, e.y);
						auto item = m_tblArticles.getItem(relativePt);
                        auto article = cast(Article)item.getData();
                        populatePopupMenu(article);

                        auto pt = m_tblArticles.getDisplay().getCursorLocation();
                        m_popupMenu.setLocation(pt.x, pt.y);
						m_popupMenu.setVisible(true);
                    }
                }
			});

		// set up sorting abilities
		auto sortListener = new SortListener;
		m_colTitle.addListener(SWT.Selection, sortListener);
		m_colAuthor.addListener(SWT.Selection, sortListener);
		m_colDate.addListener(SWT.Selection, sortListener);
		m_tblArticles.addListener(SWT.SetData, new CallbackListener);

		// set tooltip abilities
		auto labelListener = new LabelListener;
		auto tableListener = new TableListener(labelListener);
		m_tblArticles.addListener(SWT.Dispose, tableListener);
		m_tblArticles.addListener(SWT.KeyDown, tableListener);
		m_tblArticles.addListener(SWT.MouseMove, tableListener);
		m_tblArticles.addListener(SWT.MouseHover, tableListener);

		m_colAuthor.pack();
		m_colDate.pack();
		m_tblArticles.pack();
	}

	/**
	 * Change the feed content displayed in the table.
	 */
	void setFeedInfo(shared FeedInfo feedInfo)
	{
		if (feedInfo !is m_feedInfo)
		{
			m_feedInfo = feedInfo;
			int count = cast(int)m_feedInfo.getArticles().length;
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

	/**
	 * Refresh the content of the feed displayed in the table. 
	 * This method in called when a feed is refreshed and new articled have been found.
	 */
	void refresh()
	{
		int count = cast(int)m_feedInfo.getArticles().length;
		m_articles = new Rebindable!Article[count];
		foreach (index, article; m_feedInfo.getArticles())
		{
			m_articles[index] = article;
		}
		sortTable(m_sortMode);

		m_tblArticles.setItemCount(count);
		m_tblArticles.clear(0, count-1);
	}

	/**
	 * Returns a reference to the feed currently displayed by this table.
	 */
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

		auto article = cast(Article) item.getData();

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

	void setProperties(const ref Properties props)
	{
		int width = to!int(props.get("ARTICLE_TABLE_COL_TITLE_WIDTH", "280"));
		m_colTitle.setWidth(width);

		width = to!int(props.get("ARTICLE_TABLE_COL_AUTHOR_WIDTH", "100"));
		m_colAuthor.setWidth(width);

		width = to!int(props.get("ARTICLE_TABLE_COL_DATE_WIDTH", "100"));
		m_colDate.setWidth(width);
	}

	alias m_tblArticles this;
}