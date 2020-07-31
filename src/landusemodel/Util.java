package landusemodel;

import java.io.*;

public class Util {
    static PrintStream openBufferedPrintStream(String path) throws FileNotFoundException {
        FileOutputStream fileStream = new FileOutputStream(path);
        BufferedOutputStream bufStream = new BufferedOutputStream(fileStream);
        return new PrintStream(bufStream);
    }
}
