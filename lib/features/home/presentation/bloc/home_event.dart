part of 'home_bloc.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadItemsEvent extends HomeEvent {
  const LoadItemsEvent();
}

/// Shows [day] on Home (a day label: the date at midnight), or today for
/// null. Home stays on it across reloads until moved again.
class ChangeHomeDayEvent extends HomeEvent {
  final DateTime? day;

  const ChangeHomeDayEvent(this.day);

  @override
  List<Object?> get props => [day];
}
