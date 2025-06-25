// lib/features/room/view_model/room_view_model.dart

import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/models/room_model.dart';

part 'room_view_state.dart';

class RoomViewModel extends Cubit<RoomViewState> {
  final RoomService _service;
  StreamSubscription<RoomModel>? _sub;

  RoomViewModel(this._service) : super(RoomViewInitial());

  /// Firestore stream'e abone olunur
  void joinRoom(String roomId) {
    emit(RoomViewLoading());
    _sub = _service.roomStream(roomId).listen((room) {
      emit(RoomViewSynced(room: room));
    }, onError: (e) {
      emit(RoomViewError(message: e.toString()));
    });
  }

  /// Kullanıcı play/pause/seek yaptığında çağrılacak birleşik fonksiyon
  Future<void> setPlaybackState({
    required String roomId,
    required bool isPlaying,
    required double currentTime,
  }) async {
    try {
      print("YAZIYORUZ: playing=$isPlaying, time=$currentTime");

      await _service.setPlaybackState(
        roomId: roomId,
        isPlaying: isPlaying,
        currentTime: currentTime,
      );
    } catch (e) {
      // istersen log veya hata gösterimi yapabilirsin
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
