package landusemodel;

import java.util.*;

import cern.jet.random.Normal;
import cern.jet.random.Uniform;
import cern.jet.random.engine.RandomEngine;

import jstoch.model.Event;
import jstoch.model.SimulationException;

class WellMixedModel extends SuperModel
{
	Uniform unif;
	Normal betaDist;
	
	int P;
	int A;
	int F;
	int D;
	
	List<Event> dependenciesP;
	List<Event> dependenciesA;
	List<Event> dependenciesF;
	List<Event> dependenciesD;
	
	List<Double> betas;
	
	double maxBeta;
	double betaSum;
	
	PDEvent pdEvent;
	ADEvent adEvent;
	FAEvent faEvent;
	FPEvent fpEvent;
	DFEvent dfEvent;
	BetaChangeEvent bcEvent;
	
	int N;
	
	WellMixedModel(RandomEngine rng, Config config)
	{
		super(rng, config);
	}

	@Override
	public void initialize() throws SimulationException
	{
		assert(!config.useDP);
		
		unif = new Uniform(rng);
		betaDist = new Normal(0, 0.01, rng);
		
		N = config.L * config.L;
		
		P = 1;
		A = 0;
		F = N - 1;
		D = 0;
		
		betaSum = config.beta0;
		betas = new ArrayList<Double>();
		betas.add(config.beta0);
		maxBeta = config.beta0;
		
		pdEvent = new PDEvent();
		adEvent = new ADEvent();
		faEvent = new FAEvent();
		fpEvent = new FPEvent();
		dfEvent = new DFEvent();
		bcEvent = new BetaChangeEvent();
		
		dependenciesP = new ArrayList<Event>();
		dependenciesP.add(pdEvent);
		if(config.deltaF)
			dependenciesP.add(adEvent);
		dependenciesP.add(faEvent);
		dependenciesP.add(fpEvent);
		dependenciesP.add(bcEvent);
		
		dependenciesA = new ArrayList<Event>();
		dependenciesA.add(pdEvent);
		dependenciesA.add(adEvent);
		dependenciesA.add(fpEvent);
		
		dependenciesF = new ArrayList<Event>();
		if(config.deltaF)
			dependenciesF.add(adEvent);
		dependenciesF.add(faEvent);
		dependenciesF.add(fpEvent);
		if(config.epsF)
			dependenciesF.add(dfEvent);
		
		dependenciesD = new ArrayList<Event>();
		dependenciesD.add(dfEvent);
	}
	
	@Override
	public List<Event> getAllEvents()
	{
		List<Event> events = new ArrayList<Event>();
		
		// Add one of each kind of event
		events.add(pdEvent);
		events.add(adEvent);
		events.add(faEvent);
		events.add(fpEvent);
		events.add(dfEvent);
		events.add(bcEvent);
		
		return events;
	}

	@Override
	double getAvgLifetime(State state)
	{
		return 0;
	}

	@Override
	double getBetaMean()
	{
		return P == 0 ? 0 : betaSum / P;
	}

	@Override
	int getCount(State state)
	{
		switch(state)
		{
			case Populated:
				return P;
			case Agricultural:
				return A;
			case Forest:
				return F;
			case Degraded:
				return D;
		}
		return 0;
	}

	@Override
	void updateLifetimes(double time)
	{
	}
	
	class Site
	{
		int id;
		State state;
		double beta;
		double birthTime;
		
		// Maintains map from class of event to the actual event object
		// so different objects can be easily retrieved/invalidated/etc.
		public Map<Class<? extends Event>, Event> activeEvents;
		
		public Site(int id, State state)
		{
			this.id = id;
			this.state = state;
			birthTime = 0;
		}
	}
	
	class PDEvent implements Event
	{
		@Override
		public double getRate()
		{
			double numerator = 8.0 * A / N;
			
			return P * (1.0 - numerator/(numerator + config.c));
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			P--;
			D++;
			
			// Remove random beta
			int size = betas.size();
			if(size == 1)
			{
				betas.clear();
				betaSum = 0;
			}
			else
			{
				int index = unif.nextIntFromTo(0, size - 1);
				double beta = betas.get(index);
				
				// For efficiency, replace the designated beta with the one at the end
				betas.set(index, betas.get(size - 1));
				betas.remove(size - 1);
				betaSum -= beta;
			}
			
			eventsToUpdate.addAll(dependenciesP);
			eventsToUpdate.addAll(dependenciesD);
		}
	}
	
	class ADEvent implements Event
	{
		@Override
		public double getRate()
		{
			double factor = 0;
			if(config.deltaF)
			{
				if(P == 0) factor = 1.0;
				else
				{
					double numerator = Math.pow(8.0 * F / N, config.q);
					factor = 1.0 - numerator / (numerator + config.m);
				}
			}
			else
			{
				factor = config.delta;
			}
			return factor * A;
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			A--;
			D++;
			
			eventsToUpdate.addAll(dependenciesA);
			eventsToUpdate.addAll(dependenciesD);
		}
	}
	
	class FAEvent implements Event
	{
		@Override
		public double getRate()
		{
			// In the spatial model, the total rate for a single forested site
			// is the sum of all neighbors' beta rate--the well-mixed equivalent
			// is 8 * the average beta (across all sites).
			return F * 8.0 * betaSum / N;
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			F--;
			A++;
			
			eventsToUpdate.addAll(dependenciesF);
			eventsToUpdate.addAll(dependenciesA);
		}
	}
	
	class FPEvent implements Event
	{
		@Override
		public double getRate()
		{
			double f = (double)F / N;
			double p = (double)P / N;
			double a = (double)A / N;
			
			double numerator = 0;
			switch(config.productivityFunction)
			{
				case A:
					numerator = 8.0 * a;
					break;
				case AF:
					numerator = 8.0 * a * 8.0 * f / 7.0;
					break;
			}
			return F * 8.0 * p * numerator / (numerator + config.r);
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			F--;
			P++;

			// Find the beta of the invading site via simple rejection
			double beta;
			do
			{
				beta = betas.get(unif.nextIntFromTo(0, betas.size() - 1));
			} while(beta < unif.nextDouble() * maxBeta);
			
			// Copy the beta of a random populated site
			//double beta = betas.get(unif.nextIntFromTo(0, betas.size() - 1));
			betas.add(beta);
			betaSum += beta;
			
			eventsToUpdate.addAll(dependenciesF);
			eventsToUpdate.addAll(dependenciesP);
		}
	}
	
	class DFEvent implements Event
	{
		@Override
		public double getRate()
		{
			if(config.epsF)
			{
				return config.eps * D * F / N;
			}
			else
				return config.eps * D;
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			D--;
			F++;
			
			eventsToUpdate.addAll(dependenciesD);
			eventsToUpdate.addAll(dependenciesF);
		}
	}
	
	class BetaChangeEvent implements Event
	{
		@Override
		public double getRate()
		{
			return config.mu * P;
		}

		@Override
		public void performEvent(double time, Set<Event> eventsToRemove,
				Set<Event> eventsToUpdate)
		{
			// Update a random beta
			int index = unif.nextIntFromTo(0, betas.size() - 1);
			double beta = betas.get(index);
			
			betaSum -= beta;
			beta += betaDist.nextDouble();
			if(beta < 0) beta = 0;
			//else if(beta > 1) beta = 1;
			betas.set(index, beta);
			betaSum += beta;
			
			if(beta > maxBeta)
				maxBeta = beta;
			
			// Update dependent events
			eventsToUpdate.add(faEvent);
		}
	}
}
