// webapp_states.dart
abstract class WebappState {}

class WebappInitial extends WebappState {}

class WebappLoading extends WebappState {}

class WebappLoaded extends WebappState {}

class WebappError extends WebappState {
  final String message;
  WebappError(this.message);
}