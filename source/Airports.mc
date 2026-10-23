import Toybox.Lang;
import Toybox.WatchUi;

// IATA airport lookup. The data lives in resources/strings/airports.xml as one string per first letter, sorted, with
// fixed-width records (3-letter code + city name padded with "~" to RECORD chars), so entry i is found without parsing.
module Airports {

    const RECORD = 25;

    function chunkIds() as Array<ResourceId> {
        return [Rez.Strings.AptA, Rez.Strings.AptB, Rez.Strings.AptC, Rez.Strings.AptD, Rez.Strings.AptE,
            Rez.Strings.AptF, Rez.Strings.AptG, Rez.Strings.AptH, Rez.Strings.AptI, Rez.Strings.AptJ,
            Rez.Strings.AptK, Rez.Strings.AptL, Rez.Strings.AptM, Rez.Strings.AptN, Rez.Strings.AptO,
            Rez.Strings.AptP, Rez.Strings.AptQ, Rez.Strings.AptR, Rez.Strings.AptS, Rez.Strings.AptT,
            Rez.Strings.AptU, Rez.Strings.AptV, Rez.Strings.AptW, Rez.Strings.AptX, Rez.Strings.AptY,
            Rez.Strings.AptZ];
    }

    // All records for the codes starting with letter number `letter` (0 = A)
    function chunk(letter as Number) as String {
        return WatchUi.loadResource(chunkIds()[letter]) as String;
    }

    function count(data as String) as Number {
        return data.length() / RECORD;
    }

    function codeAt(data as String, i as Number) as String {
        return data.substring(i * RECORD, i * RECORD + 3) as String;
    }

    // City name of record i, without the "~" padding
    function nameAt(data as String, i as Number) as String {
        var name = data.substring(i * RECORD + 3, (i + 1) * RECORD) as String;
        var end = name.find("~");
        return end == null ? name : name.substring(0, end) as String;
    }

    // City name for a 3-letter IATA code, or null if the code is unknown
    function cityFor(code as String) as String? {
        if (code.length() != 3) {
            return null;
        }
        var upper = code.toUpper();
        var first = upper.toCharArray()[0].toNumber() - 65;   // 'A'
        if (first < 0 || first > 25) {
            return null;
        }
        var data = chunk(first);
        var lo = 0;
        var hi = count(data) - 1;
        while (lo <= hi) {
            var mid = (lo + hi) / 2;
            var c = codeAt(data, mid);
            if (c.equals(upper)) {
                return nameAt(data, mid);
            }
            if (c.compareTo(upper) < 0) {
                lo = mid + 1;
            } else {
                hi = mid - 1;
            }
        }
        return null;
    }
}
