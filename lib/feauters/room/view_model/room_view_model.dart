import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';
import 'package:watchparty/models/room_model.dart';

part 'room_view_state.dart';

class RoomViewModel extends Cubit<RoomViewState> {
  RoomViewModel(this._service) : super(RoomViewInitial());

  final RoomService _service;
  StreamSubscription<RoomModel>? _subscription;

  void joinRoom(String roomId) {
    emit(RoomViewLoading());
    _subscription?.cancel();
    _subscription = _service.roomStream(roomId).listen(
          (room) => emit(RoomViewSynced(room: room)),
          onError: (Object error) =>
              emit(RoomViewError(message: error.toString())),
        );
  }

  Future<void> setPlaybackState({
    required String roomId,
    required bool isPlaying,
    required double currentTime,
    required String updatedBy,
    required String syncEventId,
  }) {
    return _service.setPlaybackState(
      roomId: roomId,
      isPlaying: isPlaying,
      currentTime: currentTime,
      updatedBy: updatedBy,
      syncEventId: syncEventId,
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
