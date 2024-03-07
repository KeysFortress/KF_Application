import 'package:another_flushbar/flushbar.dart';
import 'package:domain/exceptions/base_exception.dart';
import 'package:flutter/material.dart';
import 'package:infrastructure/interfaces/iexception_manager.dart';
import 'package:infrastructure/interfaces/ilogging_service.dart';
import 'package:domain/styles.dart';

class ExceptionManager implements IExceptionManager {
  Flushbar? _activeBar;
  late ILoggingService _loggingService;

  ExceptionManager(ILoggingService loggingService) {
    _loggingService = loggingService;
  }

  @override
  Future raisePopup(BaseException exception) async {
    _loggingService.exception(
      exception.message ?? "",
      baseException: exception,
    );

    if (_activeBar != null) {
      await dismissBar();
    }

    _activeBar ??= Flushbar(
      onStatusChanged: (status) => barStatusChanged(status),
      padding: const EdgeInsets.all(0),
      messageText: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(0),
          margin: const EdgeInsets.all(0),
          color: ThemeStyles.theme.background200,
          child: Column(
            children: [
              const SizedBox(height: 32),
              Container(
                margin: const EdgeInsets.fromLTRB(32, 0, 32, 16),
                width: double.infinity,
                height: 5,
                decoration: BoxDecoration(
                  color: ThemeStyles.theme.accent200,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                exception.title ?? "",
                style: TextStyle(
                  color: ThemeStyles.theme.accent200,
                  letterSpacing: 2,
                  fontSize: 20,
                  fontFamily: "Loto",
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              Text(
                exception.message ?? "",
                style: TextStyle(
                  color: ThemeStyles.theme.primary300,
                  fontSize: 14,
                  letterSpacing: 2,
                  fontFamily: "Loto",
                  fontWeight: FontWeight.w400,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );

    await _activeBar!.show(exception.context);
  }

  barStatusChanged(FlushbarStatus? status) {
    if (status!.name == "DISMISSED") {
      _activeBar = null;
    }
  }

  dismissBar() async {
    if (_activeBar != null) {
      await _activeBar!.dismiss();
    }
  }
}
