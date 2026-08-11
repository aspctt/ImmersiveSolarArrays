import java.io.File;
import java.io.PrintWriter;
import java.util.Enumeration;
import java.util.TreeSet;
import java.util.zip.ZipEntry;
import java.util.zip.ZipFile;

/*
 * Writes every public method name the game's Java API exposes, one per line.
 *
 * This exists because of PropertyContainer.Is and PropertyContainer.Val. Both were
 * real in build 41, both are gone in build 42, and Lua calling a method that is not
 * there does not fail until the line runs. Placing a battery bank threw every time
 * and nothing before that point noticed.
 *
 * Names only, not per class. A call site in Lua does not say what type it is calling
 * on, so the most that can be checked without a type checker is whether the name
 * exists anywhere in the API. That is enough to catch a method the engine has
 * retired outright, which is the case that keeps happening.
 *
 * Usage: DumpApi <gameJar> <outputFile>
 */
public class DumpApi {

    public static void main(String[] args) throws Exception {
        if (args.length != 2) {
            System.out.println("usage: DumpApi <gameJar> <outputFile>");
            System.exit(2);
        }

        TreeSet<String> names = new TreeSet<String>();
        int classes = 0;
        int skipped = 0;

        ZipFile jar = new ZipFile(args[0]);
        try {
            Enumeration<? extends ZipEntry> entries = jar.entries();
            while (entries.hasMoreElements()) {
                String entry = entries.nextElement().getName();
                if (!entry.endsWith(".class")) continue;

                String className = entry.substring(0, entry.length() - 6).replace('/', '.');
                try {
                    // Resolution is off: a class whose dependencies are missing still
                    // lists its own methods, which is all this needs.
                    Class<?> c = Class.forName(className, false, DumpApi.class.getClassLoader());
                    java.lang.reflect.Method[] methods = c.getMethods();
                    for (int i = 0; i < methods.length; i++) {
                        names.add(methods[i].getName());
                    }
                    classes++;
                } catch (Throwable t) {
                    skipped++;
                }
            }
        } finally {
            jar.close();
        }

        PrintWriter out = new PrintWriter(new File(args[1]), "UTF-8");
        try {
            for (String name : names) out.println(name);
        } finally {
            out.close();
        }

        System.out.println("api names: " + names.size()
            + " from " + classes + " classes, " + skipped + " unreadable");
    }
}
