import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:injectable/injectable.dart';
import 'package:offline_alert/features/auth/domain/repository/auth_repository.dart';

/// Whether a user is signed in. Drives routing.
@lazySingleton
class SessionCubit extends Cubit<bool> {
  SessionCubit(this._auth) : super(_auth.isSignedIn) {
    _subscription = _auth.signedInChanges.listen(emit);
  }

  final AuthRepository _auth;
  late final StreamSubscription<bool> _subscription;

  Future<void> signOut() => _auth.signOut();

  @override
  @disposeMethod
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
