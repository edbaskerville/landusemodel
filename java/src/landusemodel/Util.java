package landusemodel;

import java.io.*;
import java.util.ArrayList;
import java.util.List;

public class Util {
    static PrintStream openBufferedPrintStream(String path) throws FileNotFoundException {
        FileOutputStream fileStream = new FileOutputStream(path);
        BufferedOutputStream bufStream = new BufferedOutputStream(fileStream);
        return new PrintStream(bufStream);
    }

    static double mean(double[] vals) {
        double m = 0.0;
        for (int i = 0; i < vals.length; i++) {
            m += vals[i];
        }
        return m / vals.length;
    }

    static double sd(double[] vals) {
        double m = mean(vals);
        double sumSqDev = 0.0;
        for (int i = 0; i < vals.length; i++) {
            double dev = vals[i] - m;
            sumSqDev += dev * dev;
        }
        return Math.sqrt(sumSqDev / vals.length);
    }

    static double quantile(double[] v, double p) {
        int n = v.length;
        double loc = p * (n - 1);
        double left = Math.floor(loc);
        int leftInt = (int) Math.floor(loc);
        double right = left + 1.0;
        int rightInt = leftInt + 1;

        if(rightInt <= 0) {
            return v[0];
        }
        else if(leftInt >= n - 1) {
            return v[n - 1];
        }
        else {
            return v[leftInt] + (loc - left) * (v[rightInt] - v[leftInt]);
        }
    }

    static double[] toArray(List<Double> v) {
        double[] a = new double[v.size()];
        for(int i = 0; i < a.length; i++) {
            a[i] = v.get(i);
        }
        return a;
    }

    static String formatNumber(double x) {
        if(Double.isFinite(x)) {
            return String.format("%f", x);
        }
        else {
            return "";
        }
    }
}
