enum Marketplace {
  alibaba1688('1688', '1688'),
  jd('jd', 'JD');

  final String apiKey;
  final String displayName;

  const Marketplace(this.apiKey, this.displayName);

  static Marketplace? fromApiKey(String value) {
    for (final marketplace in values) {
      if (marketplace.apiKey == value) return marketplace;
    }
    return null;
  }
}
