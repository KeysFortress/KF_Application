import 'package:domain/exceptions/base_exception.dart';
import 'package:infrastructure/interfaces/ilogging_service.dart';
import 'package:logging/logging.dart';

class LoggingService implements ILoggingService {
  late Logger _logger;

  LoggingService() {
    Logger.root.level = Level.ALL;
    Logger.root.onRecord.listen((record) => any(record));
    _logger = Logger('KeysFortress_Logs');
  }

  any(LogRecord record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  }

  @override
  info(String message) {
    _logger.info(message);
  }

  @override
  config(String message, {BaseException? baseException}) {
    _logger.config(message, baseException);
  }

  @override
  exception(
    String message, {
    BaseException? baseException,
  }) {
    _logger.finest(message, baseException);
  }

  @override
  shout(String shout, {BaseException? baseException}) {
    _logger.shout(shout, baseException);
  }

  @override
  warning(String message, {BaseException? baseException}) {
    _logger.warning(message, baseException);
  }
}
