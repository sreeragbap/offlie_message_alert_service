import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/auth_repository.dart';

/// Whether a user is signed in. Drives routing.
class SessionCubit extends Cubit<bool> {
  SessionCubit(this._auth) : super(_auth.isSignedIn) {
    _subscription = _auth.signedInChanges.listen(emit);
  }

  final AuthRepository _auth;
  late final StreamSubscription<bool> _subscription;

  Future<void> signOut() => _auth.signOut();

  @override
  Future<void> close() {
    _subscription.cancel();
    return super.close();
  }
}
