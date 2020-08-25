package jstoch.logging;

import jstoch.model.*;

public interface EventLogger
{
	public void logStart(StochasticModel model) throws LoggingException;
	public void logEnd(StochasticModel model) throws LoggingException;
	
	public void logEvent(StochasticModel model, double time, Event event) throws LoggingException;
}
