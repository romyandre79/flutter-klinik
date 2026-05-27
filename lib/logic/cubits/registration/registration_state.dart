import 'package:equatable/equatable.dart';
import 'package:kreatif_klinik/data/models/registration.dart';

abstract class RegistrationState extends Equatable {
  const RegistrationState();

  @override
  List<Object?> get props => [];
}

class RegistrationInitial extends RegistrationState {}

class RegistrationLoading extends RegistrationState {}

class RegistrationLoaded extends RegistrationState {
  final List<Registration> registrations;

  const RegistrationLoaded(this.registrations);

  @override
  List<Object?> get props => [registrations];
}

class RegistrationError extends RegistrationState {
  final String message;

  const RegistrationError(this.message);

  @override
  List<Object?> get props => [message];
}
