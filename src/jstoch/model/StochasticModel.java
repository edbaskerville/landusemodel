package jstoch.model;

import java.util.List;

public interface StochasticModel
{
	public List<Event> getAllEvents();
	public void initialize() throws SimulationException;
}
