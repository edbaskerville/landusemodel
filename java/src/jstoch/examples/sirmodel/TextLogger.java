package jstoch.examples.sirmodel;

import jstoch.logging.LoggingException;
import jstoch.logging.PeriodicLogger;
import jstoch.model.DiscreteStateModel;
import jstoch.model.StochasticModel;

public class TextLogger implements PeriodicLogger
{
	private double timeStep;
	private int logCount = 0;

	public TextLogger(double timeStep)
	{
		this.timeStep = timeStep;
	}
	
	public double getNextLogTime(StochasticModel model) throws LoggingException
	{
		return logCount * timeStep;
	}

	public void logEnd(StochasticModel model) throws LoggingException
	{			
	}

	@SuppressWarnings("unchecked")
	public void logPeriodic(StochasticModel model, double time)
			throws LoggingException
	{
		DiscreteStateModel<State> modelCast = (DiscreteStateModel<State>)model;
		System.err.printf("%f\t%d\t%d\t%d\n", time,
				modelCast.getCount(State.Susceptible), modelCast.getCount(State.Infected),
				modelCast.getCount(State.Recovered));
		logCount++;
	}

	public void logStart(StochasticModel model) throws LoggingException
	{
	}
}
