enum Marketplace {
  poizon('poizon', 'Poizon'),
  alibaba1688('1688', '1688'),
  taobao('taobao', 'Taobao');

  final String apiKey;
  final String displayName;

  const Marketplace(this.apiKey, this.displayName);
}
