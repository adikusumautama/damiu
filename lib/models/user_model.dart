// lib/models/user_model.dart
class UserModel {
  final String uid;
  final String email;
  final String? name;
  final String role;
  final String? phoneNumber;
  final String? address;

  UserModel({
    required this.uid,
    required this.email,
    this.name,
    required this.role,
    this.phoneNumber,
    this.address,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      uid: documentId,
      email: data['email'] ?? '',
      name: data['name'],
      role: data['role'] ?? 'pelanggan', // Default role jika tidak ada
      phoneNumber: data['phoneNumber'],
      address: data['address'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'phoneNumber': phoneNumber,
      'address': address,
      // uid tidak disimpan di dalam dokumen, karena uid adalah nama dokumen itu sendiri
    };
  }
}
