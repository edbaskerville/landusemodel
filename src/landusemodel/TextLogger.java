package landusemodel;

import java.io.*;
import java.util.Arrays;


import jstoch.logging.*;
import jstoch.model.*;
import landusemodel.SuperModel.State;
import static landusemodel.Util.*;

public class TextLogger implements PeriodicLogger {
	private Config config;
	private SuperModel model;
	private PrintStream stream;

	long logCount = 0;

	public TextLogger(Config config, SuperModel model) {
		this.config = config;
		this.model = model;
	}

	public void logStart(StochasticModel modelTmp) throws LoggingException {
		// Set up output file
		try {
			String filename;
			if (config.runNum == null)
				filename = "output.csv";
			else
				filename = String.format("output.%d.csv", config.runNum);

			stream = openBufferedPrintStream(filename);
			stream.printf("time,H,H_lifetime_avg,A,A_lifetime_avg,F,F_lifetime_avg,D,D_lifetime_avg,betaMean,betaSD,betaMin,betaMax,beta025,beta050,beta100,beta250,beta500,beta750,beta900,beta950,beta975\n");
			stream.flush();
		} catch (Exception e) {
			throw new LoggingException(this, e);
		}

	}

	public void logEnd(StochasticModel ignore) throws LoggingException {
		stream.close();
	}

	public double getNextLogTime(StochasticModel ignore) throws LoggingException {
		return logCount * config.logInterval;
	}

	public void logPeriodic(StochasticModel ignore, double time)
			throws LoggingException {
		model.updateLifetimes(time);

		double[] betas = model.getSortedBetas();
		if(betas.length > 0) {
			double betaMean = mean(betas);
			double betaSD = sd(betas);
			double betaMin = betas[0];
			double betaMax = betas[betas.length - 1];
			double beta025 = quantile(betas, 0.025);
			double beta050 = quantile(betas, 0.050);
			double beta100 = quantile(betas, 0.100);
			double beta250 = quantile(betas, 0.250);
			double beta500 = quantile(betas, 0.500);
			double beta750 = quantile(betas, 0.750);
			double beta900 = quantile(betas, 0.900);
			double beta950 = quantile(betas, 0.950);
			double beta975 = quantile(betas, 0.975);

			stream.printf("%f,%d,%s,%d,%s,%d,%s,%d,%s,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%f\n",
					time,
					model.getCount(State.Populated),
					formatNumber(model.getAvgLifetime(State.Populated)),
					model.getCount(State.Agricultural),
					formatNumber(model.getAvgLifetime(State.Agricultural)),
					model.getCount(State.Forest),
					formatNumber(model.getAvgLifetime(State.Forest)),
					model.getCount(State.Degraded),
					formatNumber(model.getAvgLifetime(State.Degraded)),
					betaMean, betaSD,
					betaMin, betaMax,
					beta025, beta050, beta100, beta250, beta500, beta750, beta900, beta950, beta975
			);
		}
		else {
			model.updateLifetimes(time);

			stream.printf("%f,%d,%s,%d,%s,%d,%s,%d,%s,,,,,,,,,,,,,\n",
				time,
				model.getCount(State.Populated),
				formatNumber(model.getAvgLifetime(State.Populated)),
				model.getCount(State.Agricultural),
				formatNumber(model.getAvgLifetime(State.Agricultural)),
				model.getCount(State.Forest),
				formatNumber(model.getAvgLifetime(State.Forest)),
				model.getCount(State.Degraded),
				formatNumber(model.getAvgLifetime(State.Degraded))
			);

		}

//		stream.flush();

		logCount++;
	}
}
