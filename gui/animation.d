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


class MultiAnimationThread(Widget) : Thread
{
	Image[]				m_images;
	Image[Widget]		m_targetImages;
	Widget[Widget]	    m_targets;
	immutable Duration	m_delay;
	shared bool			m_active;

	void run()
	{
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

	void remove(Widget w)
	{
		if (w !in m_targets || w !in m_targetImages)
			return;

		// restore original target image in the gui thread
		m_targets[w].setImage(m_targetImages[w]);
		m_targets.remove(w);
		m_targetImages.remove(w);

		if (m_targets.length == 0)
		{
			atomicStore(m_active, false);
		}
	}
}