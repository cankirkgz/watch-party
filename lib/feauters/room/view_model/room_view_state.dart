// lib/features/room/view_model/room_view_state.dart

part of 'room_view_model.dart';

abstract class RoomViewState {}

class RoomViewInitial extends RoomViewState {}

class RoomViewLoading extends RoomViewState {}

class RoomViewSynced extends RoomViewState {
  final RoomModel room;
  RoomViewSynced({required this.room});
}

class RoomViewError extends RoomViewState {
  final String message;
  RoomViewError({required this.message});
}
