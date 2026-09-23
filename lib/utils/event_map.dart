typedef Event = void Function(EventParameter);
typedef EventParameter = Map<String, dynamic>;

EventMap eventMap = EventMap();

class EventMap {
  static final EventMap _instance = EventMap._privateConstructor();

  factory EventMap() {
    return _instance;
  }

  late Map<String, Set<Event>> _eventMap;
  late Map<String, Set<EventParameter>> _waiting;

  EventMap._privateConstructor() {
    _eventMap = {};
    _waiting = {};
  }

  addEventListen(String event, Event function, {bool waitRun = true}) {
    if (_eventMap[event] == null) {
      _eventMap[event] = {};
    }

    _eventMap[event]?.add(function);

    //대기소에 이벤트가 있다면 실행
    if (_waiting[event] != null && waitRun) {
      for (var parameter in _waiting[event]!) {
        function.call(parameter);
      }
    }
  }

  removeEventListen(String event, Event function) {
    if (_eventMap[event] == null) {
      return;
    }
    _eventMap[event]?.remove(function);
  }

  emit(String event, EventParameter parameter) {
    // 이벤트가 null 아닐경우 전부 실행
    if (_eventMap[event] != null) {
      for (var evt in _eventMap[event]!) {
        evt.call(parameter);
      }
      return;
    }

    //이벤트가 아직 생성 전일 경우 대기상태
    if (_waiting[event] == null) {
      _waiting[event] = {};
    }
    _waiting[event]?.add(parameter);
  }
}
