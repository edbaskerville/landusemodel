package conservation;

import java.util.Date;

import jstoch.model.*;
import jstoch.parameters.Parameters;
import cern.jet.random.engine.*;

public class Main
{
	public static void main(String[] args) throws Throwable
	{
		// Load command-line parameters
		Parameters params = new Parameters(args);
		
		// Create random number generator
		RandomEngine rng;
		int rs = params.getIntValue("rs", 0);
		if(rs == 0)
			rs = (int)(new Date()).getTime();
		
		rng = new MersenneTwister(rs);
		
		// Create model and apply parameters
		Model model = new Model(rng, rs);
		params.apply(model);
		
		Simulator sim = new GillespieDirectSimulator(model, rng);
		
		sim.addPeriodicLogger(new TextLogger(model));
		if(model.outputImages)
			sim.addLogger(new ImageLogger(model));
		
		System.err.println("Start date: " + new Date());
		double T = params.getDoubleValue("T", 1000.0);
		sim.runUntil(T);
		sim.finish();
		System.err.println("End date: " + new Date());
	}
}
