import 'package:flutter_test/flutter_test.dart';
import 'package:libu_care/features/auth/data/models/auth_response_model.dart';
import 'package:libu_care/features/auth/data/models/user_model.dart';
import 'package:libu_care/features/auth/domain/entities/auth_user.dart';

void main() {
  group('UserModel', () {
    test('fromJson reads every field', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'Abebe Girma',
        'phone': '+251911234567',
        'preferredLanguage': 'en',
        'role': 'PATIENT',
      });
      expect(model.id, 'u1');
      expect(model.name, 'Abebe Girma');
      expect(model.phone, '+251911234567');
      expect(model.preferredLanguage, 'en');
      expect(model.role, 'PATIENT');
    });

    test('toDomain produces an equal AuthUser', () {
      final model = UserModel.fromJson(<String, dynamic>{
        'id': 'u1',
        'name': 'Abebe Girma',
        'phone': '+251911234567',
        'preferredLanguage': 'en',
        'role': 'PATIENT',
      });
      expect(
        model.toDomain(),
        const AuthUser(
          id: 'u1',
          name: 'Abebe Girma',
          phone: '+251911234567',
          preferredLanguage: 'en',
          role: 'PATIENT',
        ),
      );
    });
  });

  group('AuthResponseModel', () {
    test('fromJson reads the token and nests a UserModel', () {
      final model = AuthResponseModel.fromJson(<String, dynamic>{
        'token': 'header.payload.signature',
        'user': <String, dynamic>{
          'id': 'u1',
          'name': 'Abebe Girma',
          'phone': '+251911234567',
          'preferredLanguage': 'en',
          'role': 'PATIENT',
        },
      });
      expect(model.token, 'header.payload.signature');
      expect(model.user.id, 'u1');
    });
  });
}
