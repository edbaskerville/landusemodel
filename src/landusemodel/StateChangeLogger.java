package landusemodel;

import jstoch.logging.EventLogger;
import jstoch.logging.Logger;
import jstoch.logging.LoggingException;
import jstoch.model.Event;
import jstoch.model.StochasticModel;
import landusemodel.SpatialModel.Site;
import landusemodel.SuperModel.State;
import static landusemodel.Util.*;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.File;
import java.io.PrintStream;

public class StateChangeLogger implements jstoch.logging.EventLogger
{
	private Config config;
	private SpatialModel model;
	private PrintStream stream;

	public StateChangeLogger(Config config, SpatialModel model)
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
				filename = "state_changes.csv";
			else
				filename = String.format("state_changes.%d.csv", config.runNum);

			stream = openBufferedPrintStream(filename);
			stream.printf("time,row,col,P,beta\n");
		}
		catch(Exception e)
		{
			throw new LoggingException(this, e);
		}

		// Write initial state for every row/col
		for(int row = 0; row < config.L; row++) {
			for(int col = 0; col < config.L; col++) {
				writeState(0.0, row, col);
			}
		}
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
		stream.close();
	}
	
	public void logEvent(StochasticModel ignore, double time, Event event)
			throws LoggingException
	{
		Site.SiteEvent siteEvent = (Site.SiteEvent)event;
		int row = siteEvent.getRow();
		int col = siteEvent.getCol();

		if(event instanceof Site.DFPEvent || event instanceof Site.GlobalDFPEvent ||
				event instanceof Site.BetaChangeEvent || event instanceof Site.PDEvent
		) {
			writeState(time, row, col);
		}
	}

	void writeState(double time, int row, int col) {
		Site site = model.space.get(row, col);
		if(site.state == State.Populated) {
			stream.printf(
					"%f,%d,%d,%s,%f\n",
					time, row, col, 1, site.beta
			);
		}
		else {
			stream.printf(
					"%f,%d,%d,%s,\n",
					time, row, col, 0
			);
		}
	}
}
