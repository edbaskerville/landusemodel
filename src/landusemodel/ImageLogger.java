package landusemodel;

import java.awt.image.BufferedImage;
import java.io.*;

import javax.imageio.ImageIO;


import jstoch.logging.*;
import jstoch.model.*;
import landusemodel.SpatialModel.Site;

public class ImageLogger implements Logger
{
	private Config config;
	private BufferedImage image;
	private SpatialModel model;
	
	long logCount = 0;
	
	public ImageLogger(Config config, SpatialModel model)
	{
		this.config = config;
		this.model = model;
	}

	public void logStart(StochasticModel ignore) throws LoggingException
	{
		image = new BufferedImage(config.L, config.L, BufferedImage.TYPE_INT_ARGB);
		for(int row = 0; row < config.L; row++)
			for(int col = 0; col < config.L; col++)
				image.setRGB(row, col, model.space.get(row, col).state.color());
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
	}
	
	public double getNextLogTime(StochasticModel ignore) throws LoggingException
	{
		return logCount * config.imageInterval;
	}

	public void logPeriodic(StochasticModel ignore, double time)
			throws LoggingException
	{
		writeImage(time);
		
		logCount++;
	}
	
	public void logEvent(StochasticModel ignore, double time, Event event)
			throws LoggingException
	{
		Site.SiteEvent siteEvent = (Site.SiteEvent)event;
		int row = siteEvent.getRow();
		int col = siteEvent.getCol();
		Site site = model.space.get(siteEvent.getRow(), siteEvent.getCol());
		
		image.setRGB(row, col, site.state.color());
	}
	
	void writeImage(double time) throws LoggingException
	{
		String filename;
		if(config.runNum == null)
			filename = String.format("image.%04.0f.png", time);
		else
			filename = String.format("image.%d.%04.0f.png", config.runNum, time);
			
		// Write image
		try
		{
			File outputfile = new File(filename);
	        ImageIO.write(image, "png", outputfile);
		}
		catch(Exception e)
		{
			throw new LoggingException((EventLogger)this, e);
		}
	}
}
