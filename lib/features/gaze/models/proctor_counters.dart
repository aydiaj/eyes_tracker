class ProctorCounters {
  int lastTs = 0;
  int sessionMs = 0;
  int faceMissingMs = 0;
  int offScreenMs = 0;
  int lookAwayMs = 0;
  int copyEvents = 0;

  void reset() {
    lastTs = 0;
    sessionMs = 0;
    faceMissingMs = 0;
    offScreenMs = 0;
    lookAwayMs = 0;
    copyEvents = 0;
  }
}
