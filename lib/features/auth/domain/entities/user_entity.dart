import 'package:equatable/equatable.dart';

class UserEntity extends Equatable {
  final String id;
  final String email;
  final String? displayName;
  final String? avatarUrl;

  const UserEntity({
    required this.id,
    required this.email,
    this.displayName,
    this.avatarUrl,
  });

  UserEntity copyWith({
    String? id,
    String? email,
    String? displayName,
    String? avatarUrl,
  }) {
    return UserEntity(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  @override
  List<Object?> get props => [id, email, displayName, avatarUrl];
}
