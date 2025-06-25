import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:watchparty/core/utils/youtube_utils.dart';
import 'package:watchparty/feauters/home/services/home_room_creator_service.dart';
import 'package:watchparty/feauters/room/services/room_service.dart';

part 'home_view_state.dart';

class HomeViewModel extends Cubit<HomeViewState> {
  final HomeRoomCreatorService _creatorService;
  final RoomService _roomService;

  HomeViewModel({
    required HomeRoomCreatorService creatorService,
    required RoomService roomService,
  })  : _creatorService = creatorService,
        _roomService = roomService,
        super(HomeViewInitial());

  Future<void> createRoom(String youtubeUrl, String userId) async {
    emit(HomeViewLoading());

    try {
      final videoId = extractYoutubeVideoId(youtubeUrl);

      if (videoId == null) {
        emit(HomeViewError("Invalid YouTube URL"));
        return;
      }

      final roomId = await _creatorService.createRoom(
        videoId: videoId,
        createdBy: userId,
        participants: [userId],
      );
      emit(HomeViewSuccess(roomId: roomId, videoId: videoId));
    } catch (e) {
      emit(HomeViewError("Something went wrong: $e"));
    }
  }

  Future<void> getRoomById(String roomId) async {
    emit(HomeViewLoading());

    try {
      final room = await _creatorService.getRoomById(roomId);
      if (room == null) {
        emit(HomeViewError("Oda bulunamadı!"));
        return;
      }
      emit(HomeViewSuccess(roomId: room.id, videoId: room.videoId));
    } catch (e) {
      emit(HomeViewError("Bir hata oluştu: $e"));
    }
  }

  Future<void> updateRoomCurrentTime(String roomId, double currentTime) async {
    try {
      await _creatorService.updateRoomCurrentTime(
          roomId: roomId, currentTime: currentTime);
    } catch (e) {
      // Hata yönetimi eklenebilir
    }
  }
}
