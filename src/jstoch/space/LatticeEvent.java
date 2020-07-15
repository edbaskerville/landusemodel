package jstoch.space;

import jstoch.model.Event;

public interface LatticeEvent extends Event
{
	int getRow();
	int getCol();
}
