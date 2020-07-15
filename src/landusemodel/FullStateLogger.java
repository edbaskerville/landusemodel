package landusemodel;

import jstoch.logging.EventLogger;
import jstoch.logging.Logger;
import jstoch.logging.LoggingException;
import jstoch.logging.PeriodicLogger;
import jstoch.model.Event;
import jstoch.model.StochasticModel;
import landusemodel.SpatialModel.Site;

import javax.imageio.ImageIO;
import java.io.File;
import java.io.PrintStream;

public class FullStateLogger implements PeriodicLogger
{
	private Config config;
	private SpatialModel model;
	private PrintStream data;

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

			File file = new File(filename);
			data = new PrintStream(file);
			data.printf("time,row,col,birthTime,state,beta\n");
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
				data.printf(
					"%f,%d,%d,%f,%s,%f\n",
					time, row, col, site.birthTime, site.state.toString(), site.beta
				);
			}
		}
	}
}
