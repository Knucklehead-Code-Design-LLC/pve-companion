/// Converts a Unicode code point to the RFB keysym representation.
int rfbKeySymForCodePoint(int codePoint) {
  if (codePoint <= 0xff) {
    return codePoint;
  }
  return 0x01000000 | codePoint;
}
