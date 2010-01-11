package conservation;

import java.awt.image.BufferedImage;
import java.io.*;

import javax.imageio.ImageIO;

import conservation.Model.Site;

import jstoch.logging.*;
import jstoch.model.*;

public class ImageLogger implements Logger
{
	private BufferedImage image;
	private Model model;
	
	long logCount = 0;
	
	public ImageLogger(Model model)
	{
		this.model = model;
	}

	public void logStart(StochasticModel ignore) throws LoggingException
	{
		image = new BufferedImage(model.L, model.L, BufferedImage.TYPE_INT_ARGB);
		for(int row = 0; row < model.L; row++)
			for(int col = 0; col < model.L; col++)
				image.setRGB(row, col, model.space.get(row, col).state.color());
	}

	public void logEnd(StochasticModel ignore) throws LoggingException
	{
	}
	
	public double getNextLogTime(StochasticModel ignore) throws LoggingException
	{
		return logCount * model.imageInterval;
	}

	public void logPeriodic(StochasticModel ignore, double time)
			throws LoggingException
	{
		model.updateLifetimes(time);
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
		if(model.runNum == null)
			filename = String.format("image.%04.0f.png", time);
		else
			filename = String.format("image.%d.%04.0f.png", model.runNum, time);
			
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
