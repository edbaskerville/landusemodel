package jstoch.logging;

import jstoch.model.*;

public interface PeriodicLogger
{
	public void logStart(StochasticModel model) throws LoggingException;
	public void logEnd(StochasticModel model) throws LoggingException;
	
	public double getNextLogTime(StochasticModel model) throws LoggingException;
	public void logPeriodic(StochasticModel model, double time) throws LoggingException;
}
