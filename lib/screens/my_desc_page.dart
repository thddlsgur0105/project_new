import 'package:flutter/material.dart';
import 'package:flutter_application_start/screens/home_page.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class MyDescriptionPage extends StatefulWidget {
  @override
  _MyDescriptionPageState createState() => _MyDescriptionPageState();
}

class _MyDescriptionPageState extends State<MyDescriptionPage> {
  final String name = '홍길동';
  final String description = '매일매일 꾸준히..';

  String? currentUserName;
  int totalMinutes = 0;
  List<Map<String, String>> posts = [];

  // final List<Map<String, String>> posts = [
  //   {
  //     'title': '7/2 스터디 모집!',
  //     'subtitle': '오늘 스터디 참여하실 분 모집합니다 (2/4)',
  //     'time': '1m ago',
  //   },
  //   {
  //     'title': '일본어 자격증 공부 모집!',
  //     'subtitle': '일본어 자격증 준비하시는 분? \n열정 모집',
  //     'time': '8m ago',
  //   },
  // ];

  int selectedTabIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _initializeUserData();
  }

  void _initializeUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');

    if (name != null) {
      setState(() {
        currentUserName = name;
      });
      await _fetchUserPosts(name);
      await _fetchStudyTime(name);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString('userName');
    setState(() {
      currentUserName = name;
    });
  }

  Future<void> _fetchUserPosts(String username) async {
    final uri = Uri.parse('http://127.0.0.1:8000/user/$username/posts');
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        setState(() {
          posts = List<Map<String, String>>.from(
            data.map(
              (item) => {
                'title': item['title'] ?? '',
                'subtitle': item['subtitle'] ?? '',
                'time': item['time'] ?? '',
              },
            ),
          );
        });
      } else {
        print('게시글 가져오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('게시글 요청 에러: $e');
    }
  }

  Future<void> _fetchStudyTime(String username) async {
    final uri = Uri.parse(
      'http://127.0.0.1:8000/user/$username/joined-studies',
    );
    try {
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> studies = jsonDecode(response.body);
        int total = 0;

        for (var study in studies) {
          final timeMap = study['members_study_time'] as Map<String, dynamic>?;
          if (timeMap != null && timeMap.containsKey(username)) {
            total += (timeMap[username] as int);
          }
        }

        setState(() {
          totalMinutes = total;
        });
      } else {
        print('스터디 가져오기 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('공부시간 요청 에러: $e');
    }
  }

  void onTabSelected(int index) {
    setState(() {
      selectedTabIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text('프로필 정보', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.blue,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => HomePage()), // ← 홈으로
            );
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: Colors.white),
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false, // 바깥 터치로 닫히지 않도록
                builder: (context) {
                  return AlertDialog(
                    title: Text('프로필 편집'),
                    content: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          decoration: InputDecoration(labelText: '이름'),
                          // controller: nameController
                        ),
                        TextField(
                          decoration: InputDecoration(labelText: '상태 메시지'),
                          // controller: descriptionController
                        ),
                      ],
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('취소'),
                      ),
                      ElevatedButton(
                        onPressed: () {
                          // 저장 처리
                          Navigator.pop(context);
                        },
                        child: Text('저장'),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 45,
                  backgroundColor: Colors.grey,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                SizedBox(height: 12),
                Text(
                  currentUserName ?? '',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(color: Colors.black, fontSize: 14),
                ),
              ],
            ),
          ),
          Container(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => onTabSelected(0),
                    child: Text(
                      '게시글',
                      style: TextStyle(
                        color: selectedTabIndex == 0
                            ? Colors.black
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: selectedTabIndex == 0
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () => onTabSelected(1),
                    child: Text(
                      '총 공부 시간',
                      style: TextStyle(
                        color: selectedTabIndex == 1
                            ? Colors.black
                            : Colors.grey,
                        fontSize: 16,
                        fontWeight: selectedTabIndex == 1
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (index) =>
                  setState(() => selectedTabIndex = index),
              children: [
                // 게시글 탭
                ListView.builder(
                  itemCount: posts.length,
                  itemBuilder: (context, index) {
                    final post = posts[index];
                    return ListTile(
                      title: Text(
                        post['title'] ?? '',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(post['subtitle'] ?? ''),
                          SizedBox(height: 4),
                          Text(
                            post['time'] ?? '',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                // 총 공부 시간 탭
                Center(
                  child: Text(
                    '총 공부 시간: ${totalMinutes ~/ 60}시간 ${totalMinutes % 60}분',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // bottomNavigationBar: BottomNavigationBar(
      //   currentIndex: 0,
      //   onTap: (index) {
      //     // 탭 이동 처리
      //   },
      //   items: [
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.circle, size: 12),
      //       label: '',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.circle_outlined, size: 12),
      //       label: '',
      //     ),
      //     BottomNavigationBarItem(
      //       icon: Icon(Icons.circle_outlined, size: 12),
      //       label: '',
      //     ),
      //   ],
      // ),
    );
  }
}
