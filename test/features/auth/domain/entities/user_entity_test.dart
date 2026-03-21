import 'package:flutter_test/flutter_test.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';

void main() {
  const user = UserEntity(
    id: 'user-123',
    email: 'test@example.com',
    displayName: 'Test User',
    avatarUrl: 'https://example.com/avatar.png',
  );

  group('UserEntity', () {
    test('stores all fields', () {
      expect(user.id, 'user-123');
      expect(user.email, 'test@example.com');
      expect(user.displayName, 'Test User');
      expect(user.avatarUrl, 'https://example.com/avatar.png');
    });

    test('displayName and avatarUrl default to null', () {
      const minimal = UserEntity(id: 'id', email: 'e@e.com');

      expect(minimal.displayName, isNull);
      expect(minimal.avatarUrl, isNull);
    });

    test('equality based on all props', () {
      const same = UserEntity(
        id: 'user-123',
        email: 'test@example.com',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(user, equals(same));
    });

    test('inequality when any prop differs', () {
      const different = UserEntity(
        id: 'user-999',
        email: 'test@example.com',
        displayName: 'Test User',
        avatarUrl: 'https://example.com/avatar.png',
      );

      expect(user, isNot(equals(different)));
    });

    test('props contains all fields', () {
      expect(
        user.props,
        ['user-123', 'test@example.com', 'Test User', 'https://example.com/avatar.png'],
      );
    });
  });

  group('UserEntity.copyWith', () {
    test('returns new instance with updated id', () {
      final updated = user.copyWith(id: 'new-id');

      expect(updated.id, 'new-id');
      expect(updated.email, user.email);
      expect(updated.displayName, user.displayName);
      expect(updated.avatarUrl, user.avatarUrl);
    });

    test('returns new instance with updated email', () {
      final updated = user.copyWith(email: 'new@email.com');

      expect(updated.email, 'new@email.com');
      expect(updated.id, user.id);
    });

    test('returns new instance with updated displayName', () {
      final updated = user.copyWith(displayName: 'New Name');

      expect(updated.displayName, 'New Name');
    });

    test('returns new instance with updated avatarUrl', () {
      final updated = user.copyWith(avatarUrl: 'https://new.url');

      expect(updated.avatarUrl, 'https://new.url');
    });

    test('preserves all fields when no arguments given', () {
      final copy = user.copyWith();

      expect(copy, equals(user));
      expect(identical(copy, user), isFalse);
    });
  });
}
