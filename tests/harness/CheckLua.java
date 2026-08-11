import java.io.File;
import java.io.FileInputStream;
import java.io.InputStream;
import java.util.ArrayList;
import java.util.List;

import se.krka.kahlua.j2se.J2SEPlatform;
import se.krka.kahlua.luaj.compiler.LuaCompiler;
import se.krka.kahlua.vm.KahluaTable;

/*
 * Compiles every mod Lua file with the compiler Project Zomboid itself uses, so a syntax
 * error is caught here rather than at the loading screen. Nothing is executed: this only
 * answers "would the game be able to parse this file".
 *
 * Usage: CheckLua @<listFile>
 * The list file holds one path per line, which keeps the mod's spaces in folder names
 * out of the argument parsing. Run with the game directory as the working directory,
 * because Kahlua resolves stdlib.lua relative to it.
 */
public class CheckLua {

    public static void main(String[] args) throws Exception {
        if (args.length != 1 || !args[0].startsWith("@")) {
            System.out.println("usage: CheckLua @<listFile>");
            System.exit(2);
        }

        List<String> paths = new ArrayList<String>();
        java.io.BufferedReader reader = new java.io.BufferedReader(
            new java.io.InputStreamReader(new FileInputStream(args[0].substring(1)), "UTF-8"));
        try {
            String line;
            while ((line = reader.readLine()) != null) {
                line = line.trim();
                if (!line.isEmpty()) paths.add(line);
            }
        } finally {
            reader.close();
        }

        J2SEPlatform platform = new J2SEPlatform();
        KahluaTable env = platform.newEnvironment();

        List<String> failures = new ArrayList<String>();
        int compiled = 0;

        for (String path : paths) {
            File file = new File(path);
            InputStream in = new FileInputStream(file);
            try {
                LuaCompiler.loadis(in, file.getName(), env);
                compiled++;
            } catch (Exception e) {
                failures.add(path + "\n    " + rootCause(e));
            } finally {
                in.close();
            }
        }

        System.out.println("compiled " + compiled + "/" + paths.size() + " lua files");
        for (String failure : failures) {
            System.out.println("FAIL  " + failure);
        }
        System.exit(failures.isEmpty() ? 0 : 1);
    }

    private static String rootCause(Throwable t) {
        while (t.getCause() != null && t.getCause() != t) t = t.getCause();
        String message = t.getMessage();
        return message == null ? t.toString() : message;
    }
}
