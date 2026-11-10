import 'dart:async';
import 'package:flutter/foundation.dart';
import '../database/local_database.dart';
import '../models/moment.dart';

class MomentRepository extends ChangeNotifier {
  final LocalDatabase _db;
  StreamSubscription? _sub;

  MomentRepository(this._db) {
    _sub = _db.changes.listen((event) {
      if (event.table == 'moments') {
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // --- CRUD: CREATE ---
  Future<void> createMoment(Moment moment) async {
    await _db.insert('moments', moment.id, moment.toJson());
    notifyListeners();
  }

  // --- CRUD: READ ---
  List<Moment> getAllMoments() {
    final list = _db.getAll('moments');
    return list.map((json) => Moment.fromJson(json)).toList();
  }

  Moment? getMomentById(String id) {
    final data = _db.get('moments', id);
    if (data == null) return null;
    return Moment.fromJson(data);
  }

  // --- CRUD: UPDATE ---
  Future<void> updateMoment(Moment moment) async {
    await _db.update('moments', moment.id, moment.toJson());
    notifyListeners();
  }

  Future<void> toggleReaction(String id, String type) async {
    final moment = getMomentById(id);
    if (moment == null) return;

    if (moment.userReaction == type) {
      // Toggle off! Decrement reaction
      int newHeart = moment.heartCount;
      int newMood = moment.moodCount;
      int newCeleb = moment.celebrationCount;
      if (type == 'heart' && newHeart > 0) newHeart--;
      if (type == 'mood' && newMood > 0) newMood--;
      if (type == 'celebration' && newCeleb > 0) newCeleb--;

      final updated = moment.copyWith(
        userReaction: null,
        heartCount: newHeart,
        moodCount: newMood,
        celebrationCount: newCeleb,
        userLiked: false,
      );
      await updateMoment(updated);
      return;
    }

    // Toggle on or switch reaction
    int newHeart = moment.heartCount;
    int newMood = moment.moodCount;
    int newCeleb = moment.celebrationCount;

    // Decrement previous if existed
    if (moment.userReaction == 'heart' && newHeart > 0) newHeart--;
    if (moment.userReaction == 'mood' && newMood > 0) newMood--;
    if (moment.userReaction == 'celebration' && newCeleb > 0) newCeleb--;

    // Increment newly chosen
    if (type == 'heart') newHeart++;
    if (type == 'mood') newMood++;
    if (type == 'celebration') newCeleb++;

    final updated = moment.copyWith(
      userReaction: type,
      heartCount: newHeart,
      moodCount: newMood,
      celebrationCount: newCeleb,
      userLiked: type == 'heart',
    );
    await updateMoment(updated);
  }

  Future<void> toggleLike(String id) async {
    await toggleReaction(id, 'heart');
  }

  Future<void> incrementReaction(String id, String type) async {
    await toggleReaction(id, type);
  }

  // --- Comments CRUD ---
  Future<void> addComment(String momentId, String text) async {
    final moment = getMomentById(momentId);
    if (moment == null || text.trim().isEmpty) return;

    final newComment = MomentComment(
      id: 'c_${DateTime.now().millisecondsSinceEpoch}',
      authorName: 'Richard MARE',
      authorAvatar: '',
      text: text.trim(),
      timeAgo: 'À l\'instant',
    );

    final updatedList = List<MomentComment>.from(moment.comments)..add(newComment);
    final updated = moment.copyWith(
      comments: updatedList,
      commentCount: updatedList.length,
    );
    await updateMoment(updated);
  }

  Future<void> toggleCommentLike(String momentId, String commentId) async {
    final moment = getMomentById(momentId);
    if (moment == null) return;

    final updatedList = moment.comments.map((c) {
      if (c.id == commentId) {
        final liked = !c.userLiked;
        return c.copyWith(
          userLiked: liked,
          likes: liked ? c.likes + 1 : (c.likes > 0 ? c.likes - 1 : 0),
        );
      }
      return c;
    }).toList();

    await updateMoment(moment.copyWith(comments: updatedList));
  }

  // --- CRUD: DELETE ---
  Future<void> deleteMoment(String id) async {
    await _db.delete('moments', id);
    notifyListeners();
  }
}
