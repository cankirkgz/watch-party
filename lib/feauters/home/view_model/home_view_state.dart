part of 'home_view_model.dart';

abstract class HomeViewState {}

class HomeViewInitial extends HomeViewState {}

class HomeViewLoading extends HomeViewState {}

class HomeViewSuccess extends HomeViewState {
  final String roomId;
  final String videoId;
  HomeViewSuccess({required this.roomId, required this.videoId});
}

class HomeViewError extends HomeViewState {
  final String message;
  HomeViewError(this.message);
}
