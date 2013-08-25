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

module main;

import org.eclipse.swt.graphics.Point;
import org.eclipse.swt.graphics.Rectangle;
import org.eclipse.swt.widgets.Display;
import org.eclipse.swt.widgets.Shell;

import std.array;
import std.concurrency;
import std.file;
import std.path;
import std.string;

import feed;
import gui.mainwindow;
import system;

import org.eclipse.swt.widgets.MessageBox;
import org.eclipse.swt.SWT;
import std.conv;


/**
* Calculates what dimensions to give to a window, depending on a screen 
* size.
*/
void calculateWindowSize(Display display, out int w, out int h)
{
	h = cast(int)(display.getClientArea().height * 0.8);
	w = cast(int)(h * 1.33);
}

/**
 * Modelizes our application
 */
class Application
{
	Tid[] m_threadIds;

	/**
	 * Centers a window on the screen
	 */
	void center(MainWindow shell)
	{
		Rectangle bds = shell.getDisplay().getBounds();

        Point p = shell.getSize();

        int nLeft = (bds.width - p.x) / 2;
        int nTop = (bds.height - p.y) / 2;

        shell.setBounds(nLeft, nTop, p.x, p.y);
	}

public: 
	this(Display display)
	{
		// create our main window
		MainWindow win = new MainWindow(display);
		win.loadProperties();
		win.open();

		while (!win.isDisposed())
		{
			if (!display.readAndDispatch())
				display.sleep();
		}
		win.dispose();
	}

	/**
	 * This function parses the files on disk that contain serialized 
	 * FeedInfo object and deserializes them.
	 */
	static FeedInfo[] getFeedsFromDisk()
	out (result)
	{
		assert (result !is null);
	}
	body
	{
		// find/create settings directory
		auto result = appender!(FeedInfo[])();
		string settingsPath = getSettingsDirectory();
		if (!exists(settingsPath))
			mkdir(settingsPath);

		// find/create feeds directory
		string feedsPath = buildPath(settingsPath, "feeds");
		if (!exists(feedsPath))
			mkdir(feedsPath);

		
		foreach (filename; dirEntries(feedsPath, SpanMode.breadth))
		{
			auto content = readText(filename);
			//loadFromJSON(content, result);// TODO
		}

		return result.data();
	}

	static void setCurrentDir()
	{
		string path = getApplicationPath();
		chdir(path);
	}
}

int main(string[] argv)
{
	Application.setCurrentDir();	

	if (argv.length > 1)
	{
		foreach (arg; argv)
		{
			auto msgbox = new org.eclipse.swt.widgets.MessageBox.MessageBox(null, SWT.ICON_ERROR | SWT.OK);
			msgbox.setText("Arguments");
			msgbox.setMessage(to!string(arg));
			msgbox.open();
		}
	}

	auto s = getUserLanguage();
	Display display = new Display();
	new Application(display);
	display.dispose();
	
	return 0;
}
