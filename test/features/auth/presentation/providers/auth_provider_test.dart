import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nutrilens/features/auth/domain/entities/user_entity.dart';
import 'package:nutrilens/features/auth/domain/repositories/auth_repository.dart';
import 'package:nutrilens/features/auth/presentation/providers/auth_provider.dart';

class MockAuthRepository extends Mock implements AuthRepository {}

void main() {
  test('currentUserProvider follows auth state changes', () async {
    final authState = StreamController<UserEntity?>();
    final repository = MockAuthRepository();
    const oldUser = UserEntity(id: 'old-user', email: 'old@example.com');
    const newUser = UserEntity(id: 'new-user', email: 'new@example.com');

    when(() => repository.authStateChanges())
        .thenAnswer((_) => authState.stream);
    when(() => repository.currentUser).thenReturn(oldUser);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(authState.close);

    expect(container.read(currentUserProvider), oldUser);

    final emitted = Completer<UserEntity?>();
    container.listen<AsyncValue<UserEntity?>>(
      authStateProvider,
      (_, next) {
        next.whenData((user) {
          if (!emitted.isCompleted) emitted.complete(user);
        });
      },
      fireImmediately: true,
    );
    await Future<void>.delayed(Duration.zero);
    authState.add(newUser);
    await expectLater(emitted.future, completion(newUser));

    expect(container.read(currentUserProvider), newUser);
  });
}
