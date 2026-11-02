import 'package:equatable/equatable.dart';

class Profile extends Equatable {
  const Profile({required this.email, required this.displayName});

  final String? email;
  final String? displayName;

  factory Profile.fromJson(Map<String, dynamic> json) =>
      Profile(email: json['email'] as String?, displayName: json['displayName'] as String?);

  @override
  List<Object?> get props => [email, displayName];
}
