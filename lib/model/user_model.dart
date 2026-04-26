class AppUser {
  final String uid;
  final String name;
  final String email;
  final String phone;
  final String? profileImageUrl;
  final bool isLocationSharingEnabled;


  AppUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    this.profileImageUrl,
    required this.isLocationSharingEnabled,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    return AppUser(
      uid: uid,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      profileImageUrl: data['profileImageUrl'],
      isLocationSharingEnabled: data['isLocationSharingEnabled'] ?? true,
    );
  }
}
