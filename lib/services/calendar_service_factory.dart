import 'calendar_service.dart';
import 'calendar_service_stub.dart'
    if (dart.library.io) 'calendar_service_io.dart';

CalendarService createCalendarServiceImpl() => createCalendarServicePlatform();
