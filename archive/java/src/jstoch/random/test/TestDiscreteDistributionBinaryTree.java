package jstoch.random.test;

import org.junit.*;

import cern.jet.random.engine.MersenneTwister;
import cern.jet.random.engine.RandomEngine;

import java.util.*;

import jstoch.random.DiscreteDistributionBinaryTree;
import jstoch.random.StaticDiscreteDistribution;
import static org.junit.Assert.*;


public class TestDiscreteDistributionBinaryTree
{
	RandomEngine rng;
	HashMap<Integer, Double> weights;
	DiscreteDistributionBinaryTree<Integer> dist;
	
	@Before
	public void setUp()
	{
		rng = new MersenneTwister();
		weights = new HashMap<Integer, Double>();
	}
	
	@Test
	public void firstLevel()
	{
		weights.put(0, 0.1);
		weights.put(1, 0.2);
		weights.put(2, 0.3);
		weights.put(3, 0.4);
		weights.put(4, 0.5);
		weights.put(5, 0.6);
		weights.put(6, 0.7);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		List<Object> tree = dist.getTree();
		
		assertTrue(dist.getTotalWeight() < 2.81 && dist.getTotalWeight() > 2.79);
		
		System.err.println(tree);
	}
	
	@Test
	public void allLevelsIdenticalNodes()
	{
		for(int i = 0; i < 16; i++) weights.put(i, 1.0);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		List<Object> tree = dist.getTree();
		
		System.err.println(tree);
	}
	
	@Test
	public void allLevelsIdenticalNodesIncomplete()
	{
		for(int i = 0; i < 10; i++) weights.put(i, 1.0);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		List<Object> tree = dist.getTree();
		
		System.err.println(tree);
	}
	
	@Test
	public void testStatic()
	{
		weights.put(0, 0.1);
		weights.put(1, 0.2);
		weights.put(2, 0.7);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		assertTrue(dist.verify(100000));
	}
	
	@Test
	public void multipleDistUpdate()
	{
		weights.put(0, 0.1);
		weights.put(1, 0.2);
		weights.put(2, 0.7);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		dist.update(2, 0.5);
		dist.update(1, 100.0);
		
		assertTrue(dist.verify(1000000));
	}
	
	@Test
	public void stochasticTest()
	{
		int size = 100;
		
		weights.put(0, 0.1);
		weights.put(1, 0.2);
		weights.put(2, 0.7);
		dist = new DiscreteDistributionBinaryTree<Integer>(weights, rng);
		
		double[] weightsStatic = new double[] { 1.0, 0.5 };
		StaticDiscreteDistribution staticDist = new StaticDiscreteDistribution(weightsStatic, rng);
		
		for(int i = 0; i < 50; i++)
		{
			dist.update(i, rng.nextDouble());
		}
		
		for(int i = 0; i < size; i++)
		{
			int value = Math.abs(rng.nextInt()) % size;
			
			switch(staticDist.nextInt())
			{
				case 0:
					dist.update(value, rng.nextDouble());
					break;
				case 1:
					dist.remove(value);
			}
			assertTrue(dist.verify(10000));
		}
	}
}
