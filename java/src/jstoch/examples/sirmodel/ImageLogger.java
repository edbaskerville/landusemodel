package jstoch.examples.sirmodel;

import java.awt.image.BufferedImage;
import java.io.File;

import javax.imageio.ImageIO;

import jstoch.logging.EventLogger;
import jstoch.logging.Logger;
import jstoch.logging.LoggingException;
import jstoch.model.DiscreteStateModel;
import jstoch.model.Event;
import jstoch.model.StochasticModel;
import jstoch.space.DiscreteStateLatticeEvent;
import jstoch.space.Lattice;


public class ImageLogger implements Logger
{
	private int logCount = 0;
	double timeStep;
	
	private BufferedImage image;

	public ImageLogger(double timeStep)
	{
		this.timeStep = timeStep;
	}
	
	@SuppressWarnings("unchecked")
	public void logEvent(StochasticModel model, double time, Event event)
			throws LoggingException
	{
		DiscreteStateLatticeEvent<State> siteEvent = (DiscreteStateLatticeEvent<State>)event;
		int row = siteEvent.getRow();
		int col = siteEvent.getCol();
		
		image.setRGB(row, col, (siteEvent.getEndState()).color());
		
	}

	@SuppressWarnings("unchecked")
	public void logStart(StochasticModel model) throws LoggingException
	{
		int size = ((Model)model).latticeSize;
		
		Lattice<State> space = ((DiscreteStateModel<State>)model).getSpace();
		
		image = new BufferedImage(size, size, BufferedImage.TYPE_INT_ARGB);
		for(int row = 0; row < size; row++)
			for(int col = 0; col < size; col++)
				image.setRGB(row, col, space.get(row, col).color());
	}

	public double getNextLogTime(StochasticModel model)
			throws LoggingException
	{
		return timeStep * logCount;
	}

	public void logPeriodic(StochasticModel model, double time)
			throws LoggingException
	{
		String filename;
		filename = String.format("sir.%03.0f.png", time);
			
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
		
		logCount++;
	}
	
	public void logEnd(StochasticModel model) throws LoggingException
	{		
	}
}