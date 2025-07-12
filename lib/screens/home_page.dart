import 'package:flutter/material.dart';
import 'package:flutter_application_start/screens/login_page.dart';
import 'package:flutter_application_start/screens/my_desc_page.dart';
import 'package:flutter_application_start/screens/my_study_page.dart';
import 'package:flutter_application_start/screens/signup_page.dart';
import 'package:flutter_application_start/screens/study_detail_page.dart';
import 'package:flutter_application_start/screens/room_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

bool isLoggedIn = false;
String? currentUserName;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool showLoginPopup = !isLoggedIn;
  bool showCreatePopup = false;
  String searchQuery = '';
  final List<Map<String, dynamic>> studies = [];

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); // 앱 시작 시 로그인 상태 확인
  }

  // 로그인 정보를 로컬에 저장하는 함수
  Future<void> _saveLoginInfo(bool loggedIn, String? userName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', loggedIn);
    if (userName != null) {
      await prefs.setString('userName', userName);
    } else {
      await prefs.remove('userName'); // 로그아웃 시 사용자 이름 삭제
    }
    setState(() {
      isLoggedIn = loggedIn;
      currentUserName = userName;
      if (!loggedIn) {
        // 로그아웃 시 로그인 팝업 다시 띄우기
        showLoginPopup = true;
      }
    });
  }

  // 로그인 상태를 확인하고 UI를 업데이트하는 함수
  Future<void> _checkLoginStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final bool loggedIn = prefs.getBool('isLoggedIn') ?? false;
    final String? userName = prefs.getString('userName');
    setState(() {
      isLoggedIn = loggedIn;
      currentUserName = userName;
      showLoginPopup = !loggedIn; // 로그인되어 있지 않으면 팝업 표시
    });
    // 로그인 상태가 되면 스터디 목록을 새로고침
    if (isLoggedIn) {
      await fetchStudies();
    }
  }

  String _formatStudyTime(String? timeString) {
    if (timeString == null || timeString == '시간 정보 없음') return '시간 정보 없음';

    final DateTime studyTime;
    try {
      // 서버에서 받은 ISO 8601 형식의 문자열을 DateTime으로 파싱
      studyTime = DateTime.parse(timeString);
    } catch (e) {
      print('날짜 파싱 오류: $e, 원본: $timeString');
      return '시간 오류';
    }

    final now = DateTime.now();
    final difference = now.difference(studyTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      // 일주일 이상 된 경우 날짜와 시간 표시
      final DateFormat formatter = DateFormat('yyyy.MM.dd HH:mm');
      return formatter.format(studyTime);
    }
  }

  // final List<Map<String, dynamic>> studies = [
  //   {
  //     'study_index': 5,
  //     'title': '7/2 스터디 모집!',
  //     'desc': '오늘 스터디 참여하실 분 모집합니다! (2/4)',
  //     'time': '0m ago',
  //     'content': '일본어 자격증 공부 중입니다. 함께 공부해요!',
  //     'comments': ['나 재밌겠는데?', '저도 참여하고 싶어요!'],
  //   },
  //   {
  //     'study_index': 6,
  //     'title': '7/3 스터디 모집!',
  //     'desc': '내일도 모집합니다! (1/4)',
  //     'time': '4m ago',
  //     'content': '자료 공유하면서 효율적으로 공부합시다.',
  //     'comments': ['참여했습니다!', '몇 시에 시작하나요?'],
  //   },
  // ];

  Future<void> fetchStudies() async {
    final url = Uri.parse('http://127.0.0.1:8000/studies'); // 실제 서버 주소로 수정
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      setState(() {
        studies.clear();
        for (var study in data) {
          List<Map<String, dynamic>> fetchedComments = [];

          if (study['comments'] is List) {
            // comments가 List 타입인지 확인
            for (var commentData in study['comments']) {
              if (commentData is Map<String, dynamic>) {
                // 각 댓글이 Map 타입인지 확인
                fetchedComments.add(commentData);
              }
            }
          }

          studies.add({
            'study_index': study['study_index'],
            'title': study['title'],
            'desc': study['description'],
            'content': study['description_more'],
            'time': study['time'] ?? '시간 정보 없음',
            'comments': fetchedComments,
            'author': study['author'] ?? '알 수 없음',
          });
        }
      });
    } else {
      print('스터디 목록 불러오기 실패: ${response.body}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: scaffoldMessengerKey,
      home: Scaffold(
        drawer: isLoggedIn ? _buildDrawer() : null,
        appBar: _buildAppBar(),
        body: Stack(
          children: [
            _buildBody(),
            if (showLoginPopup) _buildLoginPopup(context),
            if (showCreatePopup) _buildCreateStudyPopup(),
          ],
        ),
        bottomNavigationBar: BottomAppBar(),
      ),
    );
  }

  Widget _buildBody() {
    final filteredStudies = studies.where((study) {
      return study['title']!.contains(searchQuery) ||
          study['desc']!.contains(searchQuery);
    }).toList();

    final displayedUserName = currentUserName ?? '사용자';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(height: 30),
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.black12,
            child: Icon(Icons.person, size: 60, color: Colors.black54),
          ),
          SizedBox(height: 12),
          Text(
            displayedUserName,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(isLoggedIn ? '경희대 20학번 신입 개발자' : '로그인 후 이용해 주세요.'),
          SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              OutlinedButton(
                onPressed: isLoggedIn
                    ? () => setState(() => showCreatePopup = true)
                    : null,
                child: Text('스터디 생성'),
              ),
            ],
          ),
          SizedBox(height: 20),

          if (isLoggedIn)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: TextField(
                onChanged: (value) => setState(() => searchQuery = value),
                decoration: InputDecoration(
                  hintText: '스터디 검색',
                  prefixIcon: Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.grey[200],
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(30),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),

          SizedBox(height: 20),

          if (isLoggedIn)
            Column(
              children: filteredStudies
                  .map(
                    (study) => studyCard(
                      study['study_index'] as int, // 타입 캐스팅 추가
                      study['title'] as String,
                      study['desc'] as String,
                      study['content'] as String,
                      study['time'] as String,
                      study['comments'] as List<Map<String, dynamic>>,
                      study['author'] as String,
                      {},
                      context,
                    ),
                  )
                  .toList(),
            )
          else
            Column(
              children: [
                studyCard(
                  0,
                  '로그인 후 이용 가능',
                  '로그인 후 이용 가능',
                  '내용 없음',
                  '0m ago',
                  [],
                  '알 수 없음',
                  {},
                  context,
                ),
                studyCard(
                  6,
                  '로그인 후 이용 가능',
                  '로그인 후 이용 가능',
                  '내용 없음',
                  '4m ago',
                  [],
                  '알 수 없음',
                  {},
                  context,
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildLoginPopup(BuildContext context) {
    return Center(
      child: _buildPopupContainer(
        context,
        title: '로그인 후 이용가능',
        content: '로그인 후 스터디 기능을 이용해주세요!',
        actions: [
          ElevatedButton(
            onPressed: () {
              setState(() => showLoginPopup = false); // 팝업 바로 닫기
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LoginPage()),
              ).then((_) {
                // LoginPage에서 돌아왔을 때 로그인 상태 다시 확인
                _checkLoginStatus(); // <--- 이 줄을 추가합니다.
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: Text('로그인'),
          ),
          TextButton(
            onPressed: () {
              setState(() => showLoginPopup = false); // 팝업 바로 닫기
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SignupPage()),
              ).then((_) {
                // SignupPage에서 돌아왔을 때 로그인 상태 다시 확인
                _checkLoginStatus(); // <--- 이 줄을 추가합니다.
              });
            },
            child: Text('회원 가입'),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateStudyPopup() {
    final titleController = TextEditingController();
    final descController = TextEditingController();
    final contentController = TextEditingController();

    Future<void> _submitStudy() async {
      // 입력 필드 유효성 검사 추가
      if (titleController.text.isEmpty ||
          descController.text.isEmpty ||
          contentController.text.isEmpty) {
        scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(content: Text('모든 필드를 채워주세요.')),
        );
        return; // 필드가 비어있으면 함수 종료
      }

      int maxIndex = studies.isEmpty
          ? 0
          : studies
                .map((s) => s['study_index'] as int)
                .reduce((a, b) => a > b ? a : b);

      final nextIndex = maxIndex + 1;

      final String studyAuthor = currentUserName ?? '익명';

      final url = Uri.parse('http://127.0.0.1:8000/study/create');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'study_index': nextIndex,
            'title': titleController.text,
            'description': descController.text,
            'description_more': contentController.text,
            'author': studyAuthor,
          }),
        );

        if (response.statusCode == 200) {
          await fetchStudies(); // <--- 스터디 생성 후 목록 새로고침
          setState(() => showCreatePopup = false);
          // 성공 메시지
          if (mounted) {
            scaffoldMessengerKey.currentState?.showSnackBar(
              // <--- 이 부분을 수정합니다.
              SnackBar(content: Text('스터디가 성공적으로 생성되었습니다!')),
            );
          }
        } else {
          print('스터디 생성 실패: ${response.body}');
          if (mounted) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text('오류'),
                content: Text('스터디 생성 실패: ${response.body}'), // <--- 에러 메시지 상세화
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text('확인'),
                  ),
                ],
              ),
            );
          }
        }
      } catch (e) {
        print('스터디 생성 중 오류 발생: $e');
        if (mounted) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            // <--- 이 부분을 수정합니다.
            SnackBar(content: Text('네트워크 오류가 발생했습니다.')),
          );
        }
      } finally {
        // <--- finally 블록 추가하여 항상 dispose 되도록
        titleController.dispose();
        descController.dispose();
        contentController.dispose();
      }
    }

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 20),
        padding: EdgeInsets.all(20),
        width: 320,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
        ),
        // Material 위젯 아래에 Builder 위젯을 추가합니다.
        child: Builder(
          // <--- 이 Builder 위젯을 추가합니다.
          builder: (BuildContext innerContext) {
            // <--- 새로운 context를 받습니다.
            return Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '스터디 생성',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(labelText: '제목'),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: descController,
                    decoration: InputDecoration(labelText: '간단 설명'),
                  ),
                  SizedBox(height: 10),
                  TextField(
                    controller: contentController,
                    decoration: InputDecoration(labelText: '상세 내용'),
                  ),
                  SizedBox(height: 20),
                  ElevatedButton(
                    // _submitStudy 함수를 호출할 때 innerContext를 인자로 전달합니다.
                    // 하지만 _submitStudy 내부에서 context를 사용하고 있으므로,
                    // 가장 간단한 방법은 _submitStudy 내부에 mounted 체크를 하는 것입니다.
                    onPressed: _submitStudy,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: Text(
                      '스터디 생성',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() => showCreatePopup = false);
                      titleController.dispose();
                      descController.dispose();
                      contentController.dispose();
                    },
                    child: Text('취소'),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPopupContainer(
    BuildContext context, {
    required String title,
    required String content,
    required List<Widget> actions,
  }) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 40),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(blurRadius: 10, color: Colors.black26)],
      ),
      width: 320,
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(content, textAlign: TextAlign.center),
            SizedBox(height: 20),
            ...actions,
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      iconTheme: IconThemeData(color: Colors.white),
      leading: isLoggedIn
          ? Builder(
              builder: (context) => IconButton(
                icon: Icon(Icons.menu),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            )
          : SizedBox.shrink(),
      centerTitle: true,
      title: Text('스터디 투게더', style: TextStyle(color: Colors.white)),
      backgroundColor: Colors.blue,
      actions: isLoggedIn
          ? [
              IconButton(
                icon: Icon(Icons.meeting_room), // 내 스터디방 아이콘
                tooltip: '내 스터디',
                onPressed: () {
                  // TODO: 내 스터디 페이지로 이동
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MyStudyPage(),
                    ), // 페이지 만들어야 함
                  );
                },
              ),
            ]
          : null,
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(color: Colors.blue),
            child: Text(
              '메뉴',
              style: TextStyle(color: Colors.white, fontSize: 24),
            ),
          ),
          ListTile(
            leading: Icon(Icons.home),
            title: Text('홈'),
            onTap: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.person),
            title: Text('내 정보'),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => MyDescriptionPage()),
              );
            },
          ),
          ListTile(
            leading: Icon(Icons.logout),
            title: Text('로그아웃'),
            onTap: () async {
              // <--- async 추가
              await _saveLoginInfo(false, null); // <--- 이 줄을 추가/수정합니다.
              // 홈 페이지 새로고침
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => HomePage()),
              );
            },
          ),
        ],
      ),
    );
  }
}

// 수정된 studyCard 함수
Widget studyCard(
  int study_index,
  String title,
  String subtitle,
  String content,
  String time,
  List<Map<String, dynamic>> comments,
  String author,
  Map<String, int> membersStudyTime,
  BuildContext context,
) {
  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6),
    child: Card(
      elevation: 2,
      child: ListTile(
        onTap: () async {
          final url = Uri.parse('http://127.0.0.1:8000/study/$study_index');
          final response = await http.get(url);

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);

            // 서버에서 받은 comments 데이터를 StudyDetailPage의 요구 형식에 맞게 변환
            List<Map<String, dynamic>> parsedComments = [];
            if (data['comments'] is List) {
              for (var commentData in data['comments']) {
                if (commentData is Map<String, dynamic>) {
                  parsedComments.add(commentData);
                }
              }
            }

            Map<String, int> parsedMembersStudyTime = {};
            if (data['members_study_time'] is Map) {
              data['members_study_time'].forEach((key, value) {
                parsedMembersStudyTime[key.toString()] = value as int;
              });
            }

            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => StudyDetailPage(
                  study_index: study_index,
                  title: data['title'] ?? '제목 없음',
                  description: data['description'] ?? '',
                  description_more: data['description_more'] ?? '',
                  initialComments: parsedComments,
                  author: data['author'] ?? '알 수 없음',
                ),
              ),
            );
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('스터디 정보를 불러오지 못했습니다')));
          }
        },
        leading: Icon(Icons.school, size: 40, color: Colors.blue),
        title: Text(title),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitle),
            SizedBox(height: 4),
            Text(time, style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
    ),
  );
}
