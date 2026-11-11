import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';
import 'package:watchparty/feauters/home/services/home_room_creator_service.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';

part 'home_view_state.dart';

class HomeViewModel extends Cubit<HomeViewState> {
  HomeViewModel({
    required HomeRoomCreatorService creatorService,
    required RoomService roomService,
  })  : _creatorService = creatorService,
        super(HomeViewInitial());

  final HomeRoomCreatorService _creatorService;

  Future<void> createRoom(String youtubeUrl, String userId) async {
    emit(HomeViewLoading());
    try {
      final videoId = extractYoutubeVideoId(youtubeUrl);
      if (videoId == null) {
        emit(HomeViewError('invalid-video'));
        return;
      }
      final roomId = await _creatorService.createRoom(
        videoId: videoId,
        createdBy: userId,
        participants: [userId],
      );
      emit(HomeViewSuccess(roomId: roomId, videoId: videoId));
    } catch (_) {
      emit(HomeViewError('create-failed'));
    }
  }

  Future<void> getRoomById(String roomId) async {
    emit(HomeViewLoading());
    try {
      final room = await _creatorService.getRoomById(roomId);
      if (room == null) {
        emit(HomeViewError('room-not-found'));
        return;
      }
      emit(HomeViewSuccess(roomId: room.id, videoId: room.videoId));
    } catch (_) {
      emit(HomeViewError('join-failed'));
    }
  }

  void reset() => emit(HomeViewInitial());
}
