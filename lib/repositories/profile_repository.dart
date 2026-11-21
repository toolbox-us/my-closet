import '../models/user_profile.dart';

abstract class ProfileRepository {
  Future<UserProfile> get();

  Future<void> save(UserProfile profile);

  Future<void> clear();
}
