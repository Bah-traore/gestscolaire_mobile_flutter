import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

/// Modèle utilisateur
@JsonSerializable()
class User {
  final int id;
  final String email;
  final String name;
  final String? phone;
  final String? profileImage;
  final String? userType; // 'admin', 'parent', 'student', 'teacher'
  final String? tenantId;
  final bool? isActive;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? lastLogin;

  User({
    required this.id,
    required this.email,
    required this.name,
    this.phone,
    this.profileImage,
    this.userType,
    this.tenantId,
    this.isActive,
    this.createdAt,
    this.updatedAt,
    this.lastLogin,
  });

  /// Obtenir le nom complet
  String get fullName => name;

  /// Obtenir les initiales
  String get initials {
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  /// Vérifier si l'utilisateur est un administrateur
  bool get isAdmin => userType == 'admin';

  /// Vérifier si l'utilisateur est un parent
  bool get isParent => userType == 'parent';

  /// Vérifier si l'utilisateur est un étudiant
  bool get isStudent => userType == 'student';

  /// Vérifier si l'utilisateur est un enseignant
  bool get isTeacher => userType == 'teacher';

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);
  Map<String, dynamic> toJson() => _$UserToJson(this);

  /// Copier avec modifications
  User copyWith({
    int? id,
    String? email,
    String? name,
    String? phone,
    String? profileImage,
    String? userType,
    String? tenantId,
    bool? isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? lastLogin,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImage: profileImage ?? this.profileImage,
      userType: userType ?? this.userType,
      tenantId: tenantId ?? this.tenantId,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastLogin: lastLogin ?? this.lastLogin,
    );
  }
}

/// Modèle de réponse d'authentification
@JsonSerializable()
class AuthResponse {
  @JsonKey(name: 'access_token')
  final String? accessToken;

  @JsonKey(name: 'refresh_token')
  final String? refreshToken;

  final User? user;
  final bool? success;
  final String? message;

  @JsonKey(name: 'requires_verification')
  final bool? requiresVerification;

  @JsonKey(name: 'requires_onboarding')
  final bool? requiresOnboarding;

  @JsonKey(name: 'user_id')
  final int? userId;

  AuthResponse({
    this.accessToken,
    this.refreshToken,
    this.user,
    this.success,
    this.message,
    this.requiresVerification,
    this.requiresOnboarding,
    this.userId,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) =>
      _$AuthResponseFromJson(json);
  Map<String, dynamic> toJson() => _$AuthResponseToJson(this);
}

/// Modèle de requête de connexion
@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;
  final String? tenantId;

  LoginRequest({required this.email, required this.password, this.tenantId});

  factory LoginRequest.fromJson(Map<String, dynamic> json) =>
      _$LoginRequestFromJson(json);
  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

/// Modèle de requête de réinitialisation de mot de passe
@JsonSerializable()
class ResetPasswordRequest {
  final String email;

  ResetPasswordRequest({required this.email});

  factory ResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ResetPasswordRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ResetPasswordRequestToJson(this);
}

/// Modèle de confirmation de réinitialisation de mot de passe
@JsonSerializable()
class ConfirmResetPasswordRequest {
  final String token;
  final String newPassword;

  ConfirmResetPasswordRequest({required this.token, required this.newPassword});

  factory ConfirmResetPasswordRequest.fromJson(Map<String, dynamic> json) =>
      _$ConfirmResetPasswordRequestFromJson(json);
  Map<String, dynamic> toJson() => _$ConfirmResetPasswordRequestToJson(this);
}

/// Modèle de requête d'inscription
@JsonSerializable()
class RegisterRequest {
  final String email;
  final String password;
  final String firstName;
  final String lastName;
  final String phone;

  RegisterRequest({
    required this.email,
    required this.password,
    required this.firstName,
    required this.lastName,
    required this.phone,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) =>
      _$RegisterRequestFromJson(json);
  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}
