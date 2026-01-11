/// Модель сборки для клиентского приложения
class AssemblyItem {
  final int id;
  final String number;
  final String status;
  final DateTime date;
  final int tracksCount;
  final String? tariffName;
  final String? packagingName;
  
  const AssemblyItem({
    required this.id,
    required this.number,
    required this.status,
    required this.date,
    this.tracksCount = 0,
    this.tariffName,
    this.packagingName,
  });

  factory AssemblyItem.fromJson(Map<String, dynamic> json) {
    // Получаем статус
    final statusData = json['statusData'] as Map<String, dynamic>?;
    final status = statusData?['nameRu'] as String? ?? 
                   json['status'] as String? ?? 
                   'unknown';
    
    // Получаем дату
    DateTime date;
    if (json['createdAt'] != null) {
      date = DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now();
    } else {
      date = DateTime.now();
    }
    
    // Количество треков
    final tracks = json['tracks'] as List<dynamic>?;
    final tracksCount = tracks?.length ?? json['tracksCount'] as int? ?? 0;
    
    // Тариф и упаковка
    final tariff = json['tariff'] as Map<String, dynamic>?;
    final packaging = json['packagingType'] as Map<String, dynamic>?;
    
    return AssemblyItem(
      id: json['id'] as int,
      number: json['number'] as String? ?? 'ASM-${json['id']}',
      status: status,
      date: date,
      tracksCount: tracksCount,
      tariffName: tariff?['name'] as String?,
      packagingName: packaging?['nameRu'] as String?,
    );
  }
}
