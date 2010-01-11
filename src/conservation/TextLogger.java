package conservation;

import java.io.*;

import conservation.Model.State;

import jstoch.logging.*;
import jstoch.model.*;
import jstoch.parameters.Parameters;

public class TextLogger implements PeriodicLogger
{
	private Model model;
	private PrintStream data;
	
	long logCount = 0;
	
	public TextLogger(Model model)
	{
		this.model = model;
	}
	
	public void logStart(StochasticModel modelTmp) throws LoggingException
	{
		// Set up output file
		try
		{
			String filename;
			if(model.runNum == null)
				filename = "output.txt";
			else
				filename = String.format("output.%d.txt", model.runNum);
			
			File file = new File(filename);
			data = new PrintStream(file);
			data.printf("%%t\tbeta\tP\t(avg. life)\tA\t(avg. life)\tF\t(avg. life)\tD\t(avg. life)\n");
		}
		catch(Exception e)
		{
			throw new LoggingException(this, e);
		}
		
		// Write parameters file
		try
		{
			String filename;
			if(model.runNum == null)
				filename = "params.txt";
			else
				filename = String.format("params.%d.txt", model.runNum);
			
			PrintStream paramsStream = new PrintStream(filename);
			Parameters.printParameters(model, paramsStream);
			paramsStream.close();
		}
		catch(Exception e)
		{
			throw new LoggingException((PeriodicLogger)model, e);
		}
		
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
		data.close();
	}
	
	public double getNextLogTime(StochasticModel ignore) throws LoggingException
	{
		return logCount * model.logInterval;
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
