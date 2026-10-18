/// "38" for whole minutes, "37.5" otherwise.
String fmtMinutes(double minutes) => minutes == minutes.roundToDouble()
    ? minutes.toStringAsFixed(0)
    : minutes.toStringAsFixed(1);

/// JSON number: int when whole, else one decimal.
num jsonMinutes(double minutes) => minutes == minutes.roundToDouble()
    ? minutes.round()
    : double.parse(minutes.toStringAsFixed(1));
