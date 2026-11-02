/// How long until an alert goes out, as shown on delay choices.
String delayLabel(int minutes) => switch (minutes) {
      0 => 'Now',
      < 60 => 'In $minutes min',
      60 => 'In 1 hour',
      _ when minutes % 60 == 0 => 'In ${minutes ~/ 60} hours',
      _ => 'In $minutes min',
    };
