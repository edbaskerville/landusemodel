package landusemodel;

import java.io.*;


import jstoch.logging.*;
import jstoch.model.*;
import landusemodel.SuperModel.State;

public class TextLogger implements PeriodicLogger
{
	private Config config;
	private SuperModel model;
	private PrintStream data;
	
	long logCount = 0;
	
	public TextLogger(Config config, SuperModel model)
	{
		this.config = config;
		this.model = model;
	}
	
	public void logStart(StochasticModel modelTmp) throws LoggingException
	{
		// Set up output file
		try
		{
			String filename;
			if(config.runNum == null)
				filename = "output.txt";
			else
				filename = String.format("output.%d.txt", config.runNum);
			
			File file = new File(filename);
			data = new PrintStream(file);
			data.printf("%%t\tbeta\tP\t(avg. life)\tA\t(avg. life)\tF\t(avg. life)\tD\t(avg. life)\n");
		}
		catch(Exception e)
		{
			throw new LoggingException(this, e);
		}
		
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
		data.close();
	}
	
	public double getNextLogTime(StochasticModel ignore) throws LoggingException
	{
		return logCount * config.logInterval;
	}

	public void logPeriodic(StochasticModel ignore, double time)
			throws LoggingException
	{
		model.updateLifetimes(time);
		
		data.printf("%04.0f\t%01.4f\t%d\t%f\t%d\t%f\t%d\t%f\t%d\t%f\n",
				time,
				model.getBetaMean(),
				model.getCount(State.Populated),
				model.getAvgLifetime(State.Populated),
				model.getCount(State.Agricultural),
				model.getAvgLifetime(State.Agricultural),
				model.getCount(State.Forest),
				model.getAvgLifetime(State.Forest),
				model.getCount(State.Degraded),
				model.getAvgLifetime(State.Degraded));
		
		logCount++;
	}
}
