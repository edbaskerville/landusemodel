package landusemodel;

import jstoch.logging.LoggingException;
import jstoch.logging.PeriodicLogger;
import jstoch.model.StochasticModel;
import landusemodel.SpatialModel.Site;
import static landusemodel.Util.*;

import java.io.File;
import java.io.PrintStream;

public class FullStateLogger implements PeriodicLogger
{
	private Config config;
	private SpatialModel model;
	private PrintStream stream;

	long logCount = 0;

	public FullStateLogger(Config config, SpatialModel model)
	{
		this.config = config;
		this.model = model;
	}

	public void logStart(StochasticModel ignore) throws LoggingException
	{
		// Set up output file
		try {
			String filename;
			if (config.runNum == null)
				filename = "full_state.csv";
			else
				filename = String.format("full_state.%d.csv", config.runNum);

			stream = openBufferedPrintStream(filename);
			stream.printf("time,row,col,birthTime,state,beta\n");
		}
		catch(Exception e)
		{
			throw new LoggingException(this, e);
		}
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
		stream.close();
	}
	
	public double getNextLogTime(StochasticModel ignore) throws LoggingException
	{
		return logCount * config.fullStateInterval;
	}

	public void logPeriodic(StochasticModel ignore, double time)
			throws LoggingException
	{
		writeFullState(time);
		
		logCount++;
	}

	void writeFullState(double time) throws LoggingException
	{
		for(int row = 0; row < config.L; row++) {
			for(int col = 0; col < config.L; col++) {
				Site site = model.space.get(row, col);
				stream.printf(
					"%f,%d,%d,%f,%s,%f\n",
					time, row, col, site.birthTime, site.state.toString(), site.beta
				);
			}
		}
	}
}
