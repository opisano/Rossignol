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

module gui.animation;

import core.atomic;
import core.thread;
import core.time;
import java.lang.Runnable;
import org.eclipse.swt.graphics.Image;

/**
 * This class provides a way of displaying an animation on one 
 * or several widgets. 
 */
class MultiAnimationThread(Widget) : Thread
{
	/// Animation images 
	Image[]				m_images;
	/// Stores widget original images (before the animation)
	Image[Widget]		m_targetImages;
	// Set of widgets to display the animation on.
	Widget[Widget]	    m_targets;
	// Delay between each animation frame
	immutable Duration	m_delay;
	// loop flag (for terminating the thread)
	shared bool			m_active;

	void run()
	{
		// image index 
		shared int index;
		while (atomicLoad(m_active) == true)
		{
			auto disp = m_targets.byValue().front.getDisplay();
			// update widget image in the gui thread
			disp.asyncExec(new class Runnable
				{
					override public void run()
					{
						foreach (target; m_targets)
						{
							if (!target.isDisposed())
							{
								target.setImage(m_images[index]);
							}
						}
					}
				});


				// increase image index 
				int nextIndex = atomicLoad(index);
				nextIndex = ++nextIndex % m_images.length;
				if (nextIndex == 0)
					nextIndex++;
				atomicStore(index, nextIndex);

				Thread.sleep(m_delay);
		}		
	}

public:

	/**
	 * Creates an AnimationThread object. 
	 * params:
	 * widgets=widgets to display animation on.
	 * duration=period between each animation frame.
	 * images=animation frames.
	 */
	this(Widget[] widgets, Duration duration, Image[] images)
	{
		super(&run);

		foreach (w; widgets)
		{
			m_targets[w] = w;
			m_targetImages[w] = w.getImage();
		}

		m_delay = duration;
		m_images = images;
		atomicStore(m_active, true);
	}

	/**
	 * Removes a widget from the set and restores its original 
	 * image (if any), ending its animation.
	 */
	void remove(Widget w)
	{
		if (w !in m_targets || w !in m_targetImages)
			return;

		// restore original target image in the gui thread
		m_targets[w].setImage(m_targetImages[w]);
		m_targets.remove(w);
		m_targetImages.remove(w);

		// if there is no more targets, end the animation 
		// thread. 
		if (m_targets.length == 0)
		{
			atomicStore(m_active, false);
		}
	}
}