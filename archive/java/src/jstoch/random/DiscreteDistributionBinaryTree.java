package jstoch.random;

import java.util.*;

import cern.jet.random.*;
import cern.jet.random.engine.*;

public class DiscreteDistributionBinaryTree<T> extends DiscreteDistributionAbstract<T>
{
	Uniform uniform;
	
	Map<T, Integer> treeIndexes;
	List<Integer> freeIndexes; // Stack of free locations in tree (may include some non-free locations)
	int freeIndexCount; // Actual number of free locations
	
	Map<T, Double> weights;
	List<Object> tree;
	double totalWeight;
	
	public DiscreteDistributionBinaryTree(RandomEngine rng)
	{
		this(new HashMap<T, Double>(), rng);
	}
	
	public DiscreteDistributionBinaryTree(HashMap<T, Double> weights, RandomEngine rng)
	{
		this.uniform = new Uniform(rng);
		this.weights = weights;
		
		buildTree();
	}
	
	public List<Object> getTree()
	{
		return tree;
	}
	
	public double getTotalWeight()
	{
		return totalWeight;
	}
	
	private void buildTree()
	{
		List<T> zeroWeights = new ArrayList<T>();
		for(T val : weights.keySet())
		{
			double weight = weights.get(val);
			assert(weight >= 0.0);
			
			if(weight == 0.0) zeroWeights.add(val);
		}
		
		for(T val : zeroWeights) weights.remove(val);
		zeroWeights = null;
		
		int n = weights.size();
		int nFull = round2(n);
		
		// Initialize tree with null placeholders
		int treeLength = 2*nFull - 1;
		tree = new ArrayList<Object>(treeLength);
		for(int i = 0; i < treeLength; i++)
			tree.add(null);
		
		// Add leaf nodes with items, all at lowest level until final 1 or 2
		{
			int i = 0;
			int treeIndex = nFull - 1;
			int numLeft = n;
			treeIndexes = new HashMap<T, Integer>(n);
			for(T item : weights.keySet())
			{
				// Termination: adjust the tree index to the right level
				// If there's just one left, it will put it at the right level
				// If there are two left, it will put one of them at the right level
				// and set things up to be in the right place for the final iteration.
				if(i % 2 == 0)
				{
					if(numLeft == 1 || numLeft == 2)
					{
						// Final location must be a right child
						while(treeIndex != 0 && treeIndex != rightChild(parent(treeIndex)))
						{
							treeIndex = parent(treeIndex);
						}
					}
					
					// But if we're dealing with two nodes rather than one, we really need them
					// to be children of this "final location".
					if(numLeft == 2)
					{
						treeIndex = leftChild(treeIndex);
					}
				}
				
				// In all cases, put this item in the right place in the tree
				// and record its index.
				tree.set(treeIndex, item);
				treeIndexes.put(item, treeIndex);
				
				i++;
				treeIndex++;
				numLeft--;
			}
		}
		
		// Now propagate sums up from leaf nodes to root of tree, level by level.
		// Because the sum at each node only includes half of the sum
		// that must be propagated up the tree, we maintain a parallel
		// array of right-sums to mirror the left-sums stored at each node.
		{
			double[] rightSums = new double[nFull - 1];
			int levelStart = nFull - 1;
			int levelSize = nFull;
			for(int level = lgCeil(n) - 1; level >= 0; level--)
			{
				levelStart /= 2;
				levelSize /= 2;
				for(int treeIndex = levelStart; treeIndex < levelStart + levelSize; treeIndex++)
				{
					if(tree.get(treeIndex) == null)
					{
						int leftIndex = leftChild(treeIndex);
						int rightIndex = rightChild(treeIndex);
						
						Object leftChild = tree.get(leftChild(treeIndex));
						Object rightChild = tree.get(rightChild(treeIndex));
						
						// Left child null implies that right child is also null,
						// but this is ONLY true during the initial setup:
						// this is not a constraint on the data structure after item removal.
						if(leftChild != null)
						{
							double leftSum;
							double rightSum;
							if(leftChild instanceof Double)
								leftSum = (Double)leftChild + rightSums[leftIndex];
							else
								leftSum = weights.get(leftChild);
							
							if(rightChild != null)
							{
								if(rightChild instanceof Double)
									rightSum = (Double)rightChild + rightSums[rightIndex];
								else
									rightSum = weights.get(rightChild);
							}
							else rightSum = 0;
							
							tree.set(treeIndex, leftSum);
							rightSums[treeIndex] = rightSum;
						}
					}
				}
			}
			if(weights.size() == 0) totalWeight = 0.0;
			else
			{
				Object root = tree.get(0);
				if(root instanceof Double)
				{
					totalWeight = (Double)root + rightSums[0];
				}
				else
				{
					totalWeight = weights.get(root);
				}
			}
		}
		
		// Record all the free indexes, level by level
		{
			freeIndexes = new ArrayList<Integer>(nFull - n);
			
			int levelEnd = nFull * 2 - 2;
			int levelSize = nFull;
			for(int level = lgCeil(n); level >= 0; level--)
			{
				for(int treeIndex = levelEnd; treeIndex > levelEnd - levelSize; treeIndex--)
				{
					if(tree.get(treeIndex) == null) freeIndexes.add(treeIndex);
					else break;
				}
				
				levelEnd = levelEnd / 2 - 1;
				levelSize /= 2;
			}

			freeIndexCount = freeIndexes.size();
		}
	}
	
	private static int parent(int i)
	{
		return (i-1)/2;
	}
	
	private static int leftChild(int i)
	{
		return 2*i + 1;
	}
	
	private static int rightChild(int i)
	{
		return 2*i + 2;
	}
	
	private static int round2(int n)
	{
		int L = 1;
		while(L < n) L *= 2;
		return L;
	}
	
	private static int lgCeil(int n)
	{
		int i = 0;
		int L = 1;
		while(L < n)
		{
			i++;
			L *= 2;
		}
		return i;
	}
	
	public double getNullRate()
	{
		return 0;
	}
	
	public double getRejectionRate()
	{
		return 0;
	}
	
	public int getSize()
	{
		return weights.size();
	}
	
	public double getTotalRejectionRate()
	{
		return 0;
	}
	
	public double getWeight(T value)
	{
		if(!weights.containsKey(value)) return 0;
		return weights.get(value);
	}
	
	public Map<T, Double> getWeights()
	{
		return weights;
	}
	
	@SuppressWarnings("unchecked")
	public T nextValue()
	{
		if(weights.size() == 0) return null;
		
		double x = uniform.nextDoubleFromTo(0, totalWeight);
		
		double C = 0;
		int i = 0;
		
		// As described in:
		// Wong, C. K. and M. C. Easton. 1980. An efficient method for weighted sampling without replacement.
		// SIAM J. Comput. 9(1): 111-113.
		while(true)
		{
			Object node = tree.get(i);
			
			assert(node != null);
			
			if(node instanceof Double)
			{
				double Gi = (Double)node;
				if(x < (Double)node + C)
					i = leftChild(i);
				else
				{
					C += Gi;
					i = rightChild(i);
				}
			}
			else return (T)node;
		}
	}
	
	public void printTree()
	{
		int size = tree.size();
		for(int i = 0; i < size; i++)
		{
			Object obj = tree.get(i);
			String desc;
			if(obj == null) desc = "null";
			else if(obj instanceof Double) desc = obj.toString();
			else
			{
				desc = obj.toString() + " " + weights.get(obj);
			}
			System.err.printf("%d\t%s\n", i, desc);
		}
	}
	
	public void remove(T value)
	{
		update(value, 0.0);
	}
	
	@SuppressWarnings("unchecked")
	public void update(T value, double weight)
	{
		double delta;
		int treeIndex;
		
		// Addition of values not present
		if(!weights.containsKey(value))
		{
			if(weight <= 0.0) return;
			
			weights.put(value, weight);
			delta = weight;
			
			// If we're full, we just need to build a new tree from scratch
			if(freeIndexCount == 0)
			{
				buildTree();
				return;
			}
			
			// Otherwise, use the existing tree
			// Get treeIndex from free list and initialize this node
			treeIndex = popFreeIndex();
			tree.set(treeIndex, value);
			treeIndexes.put(value, treeIndex);
			
			// If parent is a leaf, move parent to other child, initialize new
			// parent with value equal to left child, and set treeIndex to parent index
			if(treeIndex != 0)
			{
				int parentIndex = parent(treeIndex);
				Object parent = tree.get(parentIndex);
				if(!(parent instanceof Double))
				{
					int newParentIndex;
					if(treeIndex == leftChild(parentIndex))
					{
						newParentIndex = rightChild(parentIndex);
					}
					else
						newParentIndex = leftChild(parentIndex);
					assert(tree.get(newParentIndex) == null);
					tree.set(newParentIndex, parent);
					treeIndexes.put((T)parent, newParentIndex);
					
					// Decrement the number of free indexes.
					// Note that new location of parent is still on free index list,
					// but will be ignored when encountered on the stack.
					freeIndexCount--;
					
					// Create a new parent with weight from the left child
					tree.set(parentIndex, new Double(weights.get(tree.get(leftChild(parentIndex)))));
					treeIndex = parentIndex;
				}
			}
		}
		
		// Modification or removal of existing values
		else
		{
			double oldWeight = weights.get(value);
			if(weight == oldWeight) return;
			
			if(weight <= 0.0)
			{
				weights.remove(value);
				delta = -oldWeight;
				
				// Set treeIndex to current location
				// Set current location to null, adding to free list
				treeIndex = treeIndexes.get(value);
				treeIndexes.remove(value);
				tree.set(treeIndex, null);
				pushFreeIndex(treeIndex);
			}
			else
			{
				weights.put(value, weight);
				delta = weight - oldWeight;
				treeIndex = treeIndexes.get(value);
			}
		}
		
		while(treeIndex > 0)
		{
			int parentIndex = parent(treeIndex);
			
			// If parents have only null children, set parent to null
			if(tree.get(leftChild(parentIndex)) == null)
			{
				if(tree.get(rightChild(parentIndex)) == null)
				{
					tree.set(parentIndex, null);
					pushFreeIndex(parentIndex);
				}
				else tree.set(parentIndex, 0.0);
			}
			else if(treeIndex == leftChild(parentIndex))
			{
				tree.set(parentIndex, (Double)tree.get(parentIndex) + delta);
			}
			treeIndex = parentIndex;
		}
		
		if(tree.get(0) == null)
		{
			totalWeight = 0.0;
		}
		else
		{
			assert(weights.size() > 0);
			totalWeight += delta;
		}
	}
	
	private int popFreeIndex()
	{
		int index;
		do
		{
			index = freeIndexes.remove(freeIndexes.size() - 1);
		} while(tree.get(index) != null);
		
		freeIndexCount--;
		
		assert(index == 0 || tree.get(parent(index)) != null);
		
		return index;
	}
	
	private void pushFreeIndex(int index)
	{
		freeIndexes.add(index);
		freeIndexCount++;
	}

	/*@Override
	public boolean verify(int numDraws)
	{
		boolean ok = true;
		
		// Make sure the counts all match
		int numWeights = weights.size();
		assert(treeIndexes.size() == numWeights);
		
		int numFree = 0;
		int numLeaf = 0;
		int numInternal = 0;
		
		int size = tree.size();
		
		// Make sure nodes are properly laid out
		for(int i = 0; i < size; i++)
		{
			Object node = tree.get(i);
			if(node == null)
			{
				numFree++;
				if(leftChild(i) < size) assert(tree.get(leftChild(i)) == null);
				if(rightChild(i) < size) assert(tree.get(rightChild(i)) == null);
			}
			else if(node instanceof Double)
			{
				numInternal++;
				if(tree.get(leftChild(i)) == null)
				{
					assert((Double)node == 0.0);
					assert(tree.get(rightChild(i)) != null);
				}
			}
			else
			{
				numLeaf++;
				if(leftChild(i) < size) assert(tree.get(leftChild(i)) == null);
				if(rightChild(i) < size) assert(tree.get(rightChild(i)) == null);
			}
		}

		
		
		return ok && super.verify(numDraws);
	}*/
}
