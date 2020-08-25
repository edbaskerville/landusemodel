package jstoch.model;
import java.util.Set;

public interface Event
{
	public void performEvent(double time, Set<Event> eventsToRemove, Set<Event> eventsToUpdate);
	public double getRate();
}
