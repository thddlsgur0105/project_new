import 'dart:async';
import 'dart:convert'; // jsonEncode를 위해 추가
import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:fl_chart/fl_chart.dart'; // <--- fl_chart import
import 'package:http/http.dart' as http; // http 요청을 위해 추가
import 'package:flutter_application_start/screens/home_page.dart'; // currentUserName을 위해 추가
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class StudyRoomPage extends StatefulWidget {
  final String title;
  final int study_index;
  final Map<String, int> initialMembersStudyTime;
  final List<Map<String, dynamic>> initialMessages;

  StudyRoomPage({
    required this.title,
    required this.study_index,
    required this.initialMembersStudyTime,
    required this.initialMessages,
  });

  @override
  _StudyRoomPageState createState() => _StudyRoomPageState();
}

class _StudyRoomPageState extends State<StudyRoomPage> {
  PageController _pageController = PageController();
  Timer? _timer;
  int _secondsElapsed = 0;
  bool _isStudying = false;

  late WebSocketChannel _channel;
  late List<Map<String, dynamic>> _messages;
  TextEditingController _chatController = TextEditingController();

  Map<String, Map<String, int>> _studyTimeLog = {}; // 날짜별 사용자별 공부 시간
  DateTime _selectedDay = DateTime.now(); // 캘린더 선택 날짜

  late Map<String, int> _membersStudyTime; // 멤버별 공부 시간을 저장할 상태 변수
  String? _currentUser; // 현재 로그인된 사용자 이름

  @override
  void initState() {
    super.initState();

    _membersStudyTime = Map<String, int>.from(widget.initialMembersStudyTime);
    _messages = List<Map<String, dynamic>>.from(widget.initialMessages);
    _currentUser =
        currentUserName; // home_page.dart에서 전역 변수 currentUserName 가져오기
    // _membersStudyTime = {'인혁': 50, '은지': 120, '상민': 30, '철민': 75};
    _fetchMembersStudyTime();

    _channel = WebSocketChannel.connect(
      Uri.parse('ws://127.0.0.1:8000/ws/chat/${widget.study_index}'),
    );

    _channel.stream.listen((message) {
      setState(() {
        _messages.add({
          'text': message,
          'isMe': message.startsWith("[${_currentUser}] "),
        });
      });
    });
  }

  void _sendMessage() {
    if (_chatController.text.trim().isNotEmpty) {
      final text = '[${_currentUser}] ${_chatController.text.trim()}';
      _channel.sink.add(text);
      _chatController.clear();
    }
  }

  Future<void> _fetchMembersStudyTime() async {
    final url = Uri.parse('http://127.0.0.1:8000/study/${widget.study_index}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          // 총 공부 시간 반영
          if (data['members_study_time'] is Map) {
            _membersStudyTime = Map<String, int>.from(
              data['members_study_time'],
            );
          }

          // 날짜별 공부 기록 반영
          if (data['study_time_log'] is Map) {
            _studyTimeLog = Map<String, Map<String, int>>.from(
              data['study_time_log'].map(
                (key, value) => MapEntry(key, Map<String, int>.from(value)),
              ),
            );
          }
        });
      } else {
        print('스터디 시간 정보 불러오기 실패: ${response.body}');
      }
    } catch (e) {
      print('스터디 시간 정보 불러오기 오류: $e');
    }
  }

  void _startTimer() {
    if (_timer == null || !_timer!.isActive) {
      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          _secondsElapsed++;
        });
      });
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _isStudying = false;
  }

  // 공부 시간 백엔드에 전송
  Future<void> _sendStudyTimeToServer(int durationMinutes) async {
    if (_currentUser == null || _currentUser == '사용자') {
      // 로그인되지 않은 경우 전송 안함
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 후 공부 시간을 기록할 수 있습니다.')));
      return;
    }

    final url = Uri.parse(
      'http://127.0.0.1:8000/study/${widget.study_index}/update_study_time',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userName': _currentUser,
          'duration_minutes': durationMinutes,
        }),
      );

      if (response.statusCode == 200) {
        final updatedData = jsonDecode(response.body);
        setState(() {
          _membersStudyTime = Map<String, int>.from(
            updatedData['members_study_time'],
          );
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('공부 시간이 업데이트되었습니다.')));
        });
      } else {
        print('공부 시간 업데이트 실패: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('공부 시간 업데이트에 실패했습니다.')));
      }
    } catch (e) {
      print('공부 시간 업데이트 오류: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다.')));
    }
  }

  void _resetAndSendTimer() {
    _pauseTimer(); // 타이머 일시 정지 (혹시 실행 중이라면)
    if (_secondsElapsed > 0) {
      final int minutesToRecord = _secondsElapsed ~/ 60; // 초를 분으로 변환
      _sendStudyTimeToServer(minutesToRecord);
    }
    setState(() {
      _secondsElapsed = 0;
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _timer = null;
    _secondsElapsed = 0;
    _isStudying = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _goToNextPage() {
    if (_pageController.page! < 3) {
      _pageController.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _goToPreviousPage() {
    if (_pageController.page! > 0) {
      _pageController.previousPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  String _formatDuration(int totalMinutes) {
    final hours = totalMinutes ~/ 60;
    final minutes = totalMinutes % 60;
    return '${hours}h ${minutes}m';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(color: Colors.white),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        backgroundColor: Colors.blue,
        title: Text(widget.title, style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(
            onPressed: _goToNextPage,
            child: Text('Next', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: PageView(
        controller: _pageController,
        children: [
          _buildStudyStatsPage(),
          _buildCalendarPage(),
          _buildChatPage(),
          _buildFocusModePage(),
        ],
      ),
    );
  }

  Widget _buildStudyStatsPage() {
    // _membersStudyTime 데이터를 공부 시간(분) 기준으로 내림차순 정렬 <--- 수정된 부분 시작
    final sortedMembers = _membersStudyTime.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // 차트 데이터 생성
    List<BarChartGroupData> barGroups = [];
    List<String> bottomTitles = []; // X축 레이블 (멤버 이름)

    // 최대 공부 시간을 찾아 차트의 Y축 범위를 설정
    double maxY = sortedMembers.isEmpty
        ? 60.0
        : sortedMembers
                  .map((e) => e.value.toDouble())
                  .reduce((a, b) => a > b ? a : b) +
              10; // 최대값보다 조금 더 크게 설정

    for (int i = 0; i < sortedMembers.length; i++) {
      final entry = sortedMembers[i];
      barGroups.add(
        BarChartGroupData(
          x: i, // 인덱스를 x 값으로 사용
          barRods: [
            BarChartRodData(
              toY: entry.value.toDouble(), // 분 단위로 표시
              color: Colors.blue,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      bottomTitles.add(entry.key);
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            // <--- Container 대신 SizedBox로 변경 및 BarChart 추가
            height: 200, // 차트 높이 조절
            child: BarChart(
              BarChartData(
                maxY: maxY, // Y축 최대값
                minY: 0,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        '${_formatDuration(rod.toY.toInt())}', // 툴팁에 포맷된 시간 표시
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 30,
                      getTitlesWidget: (value, meta) {
                        final text = bottomTitles[value.toInt()];
                        return SideTitleWidget(
                          axisSide: meta.axisSide,
                          child: Text(
                            text,
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    // <--- 💡 이 부분이 핵심 수정 사항입니다!
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        // Y축 간격이 0이 아니거나 최대값이 아닐 때만 제목을 표시 (선택 사항)
                        if (value == 0 || value == meta.max) {
                          return Container();
                        }
                        return SideTitleWidget(
                          // Text가 아닌 SideTitleWidget을 반환
                          axisSide: meta.axisSide,
                          space: 4, // 텍스트와 축 사이의 간격
                          child: Text(
                            _formatDuration(value.toInt()),
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: barGroups,
              ),
            ),
          ),
          SizedBox(height: 20),
          Row(
            children: [
              Text(
                '총 공부 시간',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 12),
          Expanded(
            child: ListView(
              children: sortedMembers.map((entry) {
                // <--- 수정된 부분: sortedMembers 사용
                return _studyTimeTile(entry.key, _formatDuration(entry.value));
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _studyTimeTile(String name, String time) {
    return ListTile(
      leading: Icon(Icons.circle, size: 10, color: Colors.blue),
      title: Text(name),
      trailing: Text(time, style: TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCalendarPage() {
    final String selectedDateStr = _selectedDay.toIso8601String().substring(
      0,
      10,
    );
    final Map<String, int> todayStudyLog = _studyTimeLog[selectedDateStr] ?? {};

    return Column(
      children: [
        TableCalendar(
          firstDay: DateTime.utc(2023, 1, 1),
          lastDay: DateTime.utc(2030, 12, 31),
          focusedDay: _selectedDay,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
            });
          },
        ),
        Expanded(
          child: todayStudyLog.isEmpty
              ? Center(child: Text("이 날의 공부 기록이 없습니다."))
              : ListView(
                  children: todayStudyLog.entries.map((entry) {
                    return _studyTimeTile(
                      entry.key,
                      _formatDuration(entry.value),
                    );
                  }).toList(),
                ),
        ),
      ],
    );
  }

  Widget _buildChatPage() {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            padding: EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              final msg = _messages[index];
              return Align(
                alignment: msg['isMe']
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  margin: EdgeInsets.symmetric(vertical: 6),
                  constraints: BoxConstraints(maxWidth: 260),
                  decoration: BoxDecoration(
                    color: msg['isMe'] ? Colors.blue : Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    msg['text'].replaceFirst('[${_currentUser}] ', ''),
                    style: TextStyle(
                      color: msg['isMe'] ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _chatController,
                  decoration: InputDecoration(
                    hintText: '메시지를 입력하세요!',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
                    contentPadding: EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
              SizedBox(width: 10),
              IconButton(
                icon: Icon(Icons.send, color: Colors.blue),
                onPressed: _sendMessage,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFocusModePage() {
    final minutes = _secondsElapsed ~/ 60;
    final seconds = _secondsElapsed % 60;

    final formattedTime =
        '${minutes.toString().padLeft(2, '0')}분 ${seconds.toString().padLeft(2, '0')}초';

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '열공 모드!',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 160,
                height: 160,
                child: CircularProgressIndicator(
                  value: (_secondsElapsed % 3600) / 3600,
                  strokeWidth: 8,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                  backgroundColor: Colors.grey[300],
                ),
              ),
              Column(
                children: [
                  Text(
                    formattedTime,
                    style: TextStyle(fontSize: 18, color: Colors.blue),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${((_secondsElapsed % 3600) / 36).toStringAsFixed(1)}% spent',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isStudying = true;
                    _startTimer();
                  });
                },
                child: Text('공부 시작!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: _pauseTimer,
                child: Text('공부 멈춤!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.black,
                ),
              ),
              SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _resetAndSendTimer();
                  });
                },
                child: Text('공부 종료!'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[100],
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
