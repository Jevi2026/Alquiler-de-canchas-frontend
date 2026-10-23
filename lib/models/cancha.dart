class Cancha {
  final int id;
  final String name;
  final String? surface;
  final double price;
  final String opensAt, closesAt;
  final String? photoUrl;
  final List<Map<String, dynamic>> reservations;
  const Cancha({
    required this.id,
    required this.name,
    this.surface,
    required this.price,
    required this.opensAt,
    required this.closesAt,
    this.photoUrl,
    this.reservations = const [],
  });
  factory Cancha.fromJson(Map<String, dynamic> j) => Cancha(
    id: j['id'] as int,
    name: j['name'] as String,
    surface: j['surface'] as String?,
    price: double.parse(j['price_per_hour'].toString()),
    opensAt: j['opens_at'].toString().substring(0, 5),
    closesAt: j['closes_at'].toString().substring(0, 5),
    photoUrl: j['photo_url'] as String?,
    reservations: (j['reservations'] as List? ?? [])
        .cast<Map<String, dynamic>>(),
  );
}
