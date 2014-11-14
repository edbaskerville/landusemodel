package landusemodel;

import java.io.FileReader;
import java.io.PrintStream;
import java.util.Date;

import jstoch.model.*;

import com.google.gson.*;

import cern.jet.random.engine.*;

public class Main
{
	public static void main(String[] args) throws Throwable
	{
		String configFilename = args[0];
		FileReader r = new FileReader(configFilename);
		Config config = (new Gson()).fromJson(r, Config.class);
		
		// Create random number generator
		if(config.randomSeed == null)
			config.randomSeed = (int)(new Date()).getTime();
		RandomEngine rng = new MersenneTwister(config.randomSeed);
		
		// Create model and apply Settings
		SuperModel model;
		if(config.spatial)
		{
			model = new SpatialModel(rng, config);
		}
		else
		{
			model = new WellMixedModel(rng, config);
		}
		
		// Write parameters file as read
		String filename;
		if(config.runNum == null)
			filename = "parameters_out.json";
		else
			filename = String.format("parameters_out.json", config.runNum);
		PrintStream paramsStream = new PrintStream(filename);
		new GsonBuilder().setPrettyPrinting().create().toJson(config, paramsStream);
		paramsStream.println();
		paramsStream.close();
		
		Simulator sim = new GillespieDirectSimulator(model, rng);
		if(config.spatial)
		{
			if(config.outputImages)
				sim.addLogger(new ImageLogger(config, (SpatialModel)model));
		}
		
		sim.addPeriodicLogger(new TextLogger(config, model));
		
		System.err.println("Start date: " + new Date());
		double T = config.maxTime;
		sim.runUntil(T);
		sim.finish();
		System.err.println("End date: " + new Date());
	}
}
