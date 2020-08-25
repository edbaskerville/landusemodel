package jstoch.model;

import cern.jet.random.*;
import cern.jet.random.engine.*;
import java.util.*;

import jstoch.logging.*;
import jstoch.random.*;

public class GillespieDirectSimulator implements Simulator
{
	private boolean initialized = false;
	private boolean finished = false;
	
	private StochasticModel model;
	private RandomEngine rng;
	
	private Set<Logger> loggers;
	private Set<EventLogger> eventLoggers;
	private Set<PeriodicLogger> periodicLoggers;
	
//	public enum DiscreteDistributionType
//	{
//		BinaryTree,
//		SimpleRejection,
//		ModifiedRejection
//	}
	
//	DiscreteDistributionType discreteDistributionType = DiscreteDistributionType.BinaryTree;
//	private double modifiedRejectionBinSize = 0.1;
	
	private double time;
	private Exponential timeDist;
	
	private DiscreteDistribution<Event> dist;
	
	private Set<Event> eventsToRemove;
	private Set<Event> eventsToUpdate;
	
	public GillespieDirectSimulator(StochasticModel model, RandomEngine rng)
	{
		time = 0;
		timeDist = new Exponential(1.0, rng);
		
		this.model = model;
		this.rng = rng;
		
		loggers = new HashSet<Logger>();
		periodicLoggers = new HashSet<PeriodicLogger>();
		eventLoggers = new HashSet<EventLogger>();
	}
	
	private void initialize() throws SimulationException
	{
		if(!initialized)
		{
			model.initialize();
			
			List<Event> events = model.getAllEvents();
			HashMap<Event, Double> rates = new HashMap<Event, Double>(events.size());
			
			for(Event event : events)
				rates.put(event, event.getRate());
			
			events = null;
			
			dist = new DiscreteDistributionBinaryTree<Event>(rates, rng);
//			switch(discreteDistributionType)
//			{
//				case BinaryTree:
//					dist = new DiscreteDistributionBinaryTree<Event>(rates, rng);
//					break;
//				case SimpleRejection:
//					dist = new DiscreteDistributionRejection<Event>(rates, rng);
//					break;
//				case ModifiedRejection:
//					dist = new DiscreteDistributionRejectionPlus<Event>(modifiedRejectionBinSize, rates, rng);
//					break;
//			}
			
			eventsToRemove = new HashSet<Event>();
			eventsToUpdate = new HashSet<Event>();
			
			try
			{
				for(Logger logger : loggers)
					logger.logStart(model);
				for(EventLogger logger : eventLoggers)
					logger.logStart(model);
				for(PeriodicLogger logger : periodicLoggers)
					logger.logStart(model);
			}
			catch(LoggingException e)
			{
				throw new SimulationException("Logging exception thrown", e);
			}
			
			initialized = true;
		}
	}
	
	public double runUntil(double endTime) throws SimulationException
	{
		if(finished) throw new SimulationException("Already finished.");
		if(!initialized) initialize();
		
		while(time < endTime)
		{
			performNextEvent();
			if(time == Double.POSITIVE_INFINITY) break;
		}
		return time;
	}
	
	public double runFor(double timestep) throws SimulationException
	{
		return runUntil(time + timestep);
	}
	
	public double performNextEvent() throws SimulationException
	{
		if(finished) throw new SimulationException("Already finished.");
		if(!initialized) initialize();
		
		double totalRate = dist.getTotalWeight();
		double tau;
		if(totalRate == 0)
			tau = Double.POSITIVE_INFINITY;
		else
			tau = timeDist.nextDouble(totalRate);
		time += tau;
		
		try
		{
			logPeriodic(time);
		}
		catch(LoggingException e)
		{
			throw new SimulationException("Logging exception thrown", e);
		}
		
		if(time != Double.POSITIVE_INFINITY)
		{
			Event event = dist.nextValue();
			event.performEvent(time, eventsToRemove, eventsToUpdate);
			
			for(Event eventToRemove : eventsToRemove)
			{
				dist.remove(eventToRemove);
			}
			eventsToRemove.clear();
			
			for(Event eventToUpdate : eventsToUpdate)
			{
				dist.update(eventToUpdate, eventToUpdate.getRate());
			}
			eventsToUpdate.clear();
			
			try
			{
				logEvent(time, event);
			}
			catch(LoggingException e)
			{
				throw new SimulationException("Logging exception thrown", e);
			}
		}
		
		return time;
	}
	
	public void finish() throws SimulationException
	{
		if(!initialized) initialize();
		
		try
		{
			for(Logger logger : loggers)
				logger.logEnd(model);
			for(EventLogger logger : eventLoggers)
				logger.logEnd(model);
			for(PeriodicLogger logger : periodicLoggers)
				logger.logEnd(model);
		}
		catch(LoggingException e)
		{
			throw new SimulationException("Logging exception thrown", e);
		}
		
		finished = true;
	}
	
	public double getTime()
	{
		return time;
	}
	
	public void addEventLogger(EventLogger logger)
	{
		eventLoggers.add(logger);
	}
	
	public void addLogger(Logger logger)
	{
		loggers.add(logger);
	}
	
	public void addPeriodicLogger(PeriodicLogger logger)
	{
		periodicLoggers.add(logger);
	}
	
	public void logPeriodic(double time) throws LoggingException
	{
		for(Logger logger : loggers)
			logPeriodic(time, logger);
		
		for(PeriodicLogger logger : periodicLoggers)
			logPeriodic(time, logger);
	}
	
	private void logPeriodic(double time, PeriodicLogger logger) throws LoggingException
	{
		boolean done = false;
		while(!done)
		{
			double nextTime = logger.getNextLogTime(model);
			if(time > nextTime) logger.logPeriodic(model, nextTime);
			else done = true;
			if(time == Double.POSITIVE_INFINITY) done = true;
		}
	}
	
	public void logEvent(double time, Event event) throws LoggingException
	{
		for(Logger logger : loggers)
			logger.logEvent(model, time, event);
		
		for(EventLogger logger : eventLoggers)
			logger.logEvent(model, time, event);
	}
}
