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
				filename = "output.csv";
			else
				filename = String.format("output.%d.csv", config.runNum);
			
			File file = new File(filename);
			data = new PrintStream(file);
			data.printf("time,beta,H,H_lifetime_avg,A,A_lifetime_avg,F,F_lifetime_avg,D,D_lifetime_avg\n");
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
		
		data.printf("%f,%f,%d,%f,%d,%f,%d,%f,%d,%f\n",
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
