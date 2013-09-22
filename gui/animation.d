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

module gui.animation;

import core.atomic;
import core.thread;
import core.time;

import java.lang.Runnable;
import org.eclipse.swt.graphics.Image;
import org.eclipse.swt.widgets.TreeItem;

import gui.mainwindow;

class AnimationTimer : Runnable
{
	// Reference to our main window
	MainWindow          m_mainWindow;	
	/// Animation images 
	Image[]				m_images;
	// The widgets to display animation image on.
	TreeItem[TreeItem]    m_controls;
    /// Stores widget original images (before the animation)
	Image[TreeItem]		m_targetImages;
	
	int m_index;

    bool m_running;
	
public:
	this(MainWindow mainWindow, TreeItem[] controls, Image[] images)
	{
		m_mainWindow = mainWindow;
		foreach (c; controls)
		{
			m_controls[c] = c;
            m_targetImages[c] = c.getImage();
		}
		m_index = 1;
		m_images = images;
	}
	
	override void run()
	{
        m_running = true;

		// Display animation images on all of our widgets.
		foreach (ctrl; m_controls)
		{
			if (!ctrl.isDisposed())
			{
				ctrl.setImage(m_images[m_index]);
			}
		}
		
		m_index = (m_index + 1) % m_images.length;
		if (m_index == 0)
		{
			++m_index;
		}
			
		// schedule next timer iteration
        if (!m_mainWindow.isDisposed())
        {
		    m_mainWindow.getDisplay().timerExec(50, this);
        }
	}
	
	/**
	 * Removes a widget from the set and restores its original 
	 * image (if any), ending its animation.
	 * 
	 * This method must be called from the GUI thread.
	 */
	void remove(TreeItem w)
	{
		if (w is null || w !in m_controls || w.isDisposed())
			return;

		// restore original target image in the gui thread
		m_controls[w].setImage(m_targetImages[w]);
		m_controls.remove(w);

		// if there is no more targets, end the animation 
		// thread. 
		if (m_controls.length == 0)
		{
			// schedule next timer iteration
			m_mainWindow.getDisplay().timerExec(-1, this);
            m_running = false;
		}
	}

    bool isRunning() const
    {
        return m_running;
    }
}