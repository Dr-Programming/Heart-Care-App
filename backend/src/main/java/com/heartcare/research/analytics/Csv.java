package com.heartcare.research.analytics;

import java.io.PrintWriter;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

/** CSV rendering for research exports. Nested values are flattened to dotted column names. */
public final class Csv {

    private Csv() {
    }

    /** Writes rows of (possibly nested) maps; the header is the union of every row's flattened keys. */
    public static int writeRows(PrintWriter out, List<Map<String, Object>> rows) {
        List<Map<String, Object>> flat = new ArrayList<>(rows.size());
        Set<String> header = new LinkedHashSet<>();
        for (Map<String, Object> row : rows) {
            Map<String, Object> f = new LinkedHashMap<>();
            row.forEach((k, v) -> put(f, k, v));
            header.addAll(f.keySet());
            flat.add(f);
        }
        out.println(String.join(",", header.stream().map(Csv::cell).toList()));
        for (Map<String, Object> f : flat) {
            out.println(String.join(",", header.stream().map(h -> cell(f.get(h))).toList()));
        }
        return rows.size();
    }

    @SuppressWarnings("unchecked")
    private static void put(Map<String, Object> flat, String key, Object value) {
        if (value instanceof Map<?, ?> m) {
            ((Map<String, Object>) m).forEach((k, v) -> put(flat, key + "." + k, v));
        } else if (value instanceof List<?> l) {
            flat.put(key, String.join("; ", l.stream().map(String::valueOf).toList()));
        } else {
            flat.put(key, value);
        }
    }

    /** Quoted, with spreadsheet formula injection neutralised. */
    public static String cell(Object value) {
        if (value == null) {
            return "";
        }
        String s = value.toString();
        if (!s.isEmpty() && "=+-@".indexOf(s.charAt(0)) >= 0 && !isNumber(s)) {
            s = "'" + s;
        }
        return "\"" + s.replace("\"", "\"\"") + "\"";
    }

    private static boolean isNumber(String s) {
        try {
            Double.parseDouble(s);
            return true;
        } catch (NumberFormatException e) {
            return false;
        }
    }
}
