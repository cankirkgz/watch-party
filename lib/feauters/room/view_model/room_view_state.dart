part of 'room_view_model.dart';

sealed class RoomViewState {}

class RoomViewInitial extends RoomViewState {}

class RoomViewLoading extends RoomViewState {}

class RoomViewSynced extends RoomViewState {
  RoomViewSynced({required this.room});
  final RoomModel room;
}

class RoomViewError extends RoomViewState {
  RoomViewError({required this.message});
  final String message;
}
