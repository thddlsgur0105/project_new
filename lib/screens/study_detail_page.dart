import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_start/screens/home_page.dart';
import 'package:intl/intl.dart';

class StudyDetailPage extends StatefulWidget {
  final String title;
  final String description;
  final String description_more;
  // final List<String> initialComments;
  final List<Map<String, dynamic>> initialComments;
  final int study_index;
  final String author;

  StudyDetailPage({
    required this.study_index,
    required this.title,
    required this.description,
    required this.description_more,
    required this.initialComments,
    required this.author,
  });

  @override
  _StudyDetailPageState createState() => _StudyDetailPageState();
}

class _StudyDetailPageState extends State<StudyDetailPage> {
  final TextEditingController _controller = TextEditingController();
  late List<Map<String, dynamic>> comments;
  bool _isJoining = false;

  @override
  void initState() {
    super.initState();
    comments = List<Map<String, dynamic>>.from(widget.initialComments);
  }

  // DateTime 객체를 받아 '방금 전', 'N분 전', 'YYYY.MM.DD HH:mm' 형태로 포맷하는 함수
  String _formatCommentTime(String? timeString) {
    if (timeString == null) return '';

    final DateTime commentTime;
    try {
      commentTime = DateTime.parse(timeString);
    } catch (e) {
      print('날짜 파싱 오류: $e, 원본: $timeString');
      return ''; // 파싱 실패 시 빈 문자열 반환
    }

    final now = DateTime.now();
    final difference = now.difference(commentTime);

    if (difference.inSeconds < 60) {
      return '방금 전';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}분 전';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}시간 전';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}일 전';
    } else {
      // 그 외의 경우, 날짜와 시간을 포맷하여 반환
      final DateFormat formatter = DateFormat('yyyy.MM.dd HH:mm');
      return formatter.format(commentTime);
    }
  }

  Future<void> _sendComment() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final author = currentUserName ?? '익명'; // 로그인되어 있지 않을 때 기본값 설정
    final now = DateTime.now(); // 현재 시간 가져오기
    final time = now.toIso8601String(); // ISO 8601 형식의 문자열로 변환 (서버 전송용)

    final url = Uri.parse(
      'http://127.0.0.1:8000/study/${widget.study_index}/comment',
    );

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'author': author, 'text': text, 'time': time}),
      );

      if (response.statusCode == 200) {
        setState(() {
          comments.add({'author': author, 'text': text, 'time': time});
          _controller.clear();
        });
      } else {
        print('댓글 추가 실패: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('댓글 등록에 실패했습니다.')));
      }
    } catch (e) {
      print('오류 발생: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다.')));
    }
  }

  Future<void> _joinStudy() async {
    if (_isJoining) return; // 중복 요청 방지

    setState(() {
      _isJoining = true; // 로딩 시작
    });

    final userName = currentUserName; // 로그인된 사용자 이름 가져오기 (home_page.dart에서 정의)
    if (userName == null || userName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('로그인 후 스터디에 참여할 수 있습니다.')));
      setState(() {
        _isJoining = false; // 로딩 종료
      });
      return;
    }

    final url = Uri.parse('http://127.0.0.1:8000/user/join-study');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': userName,
          'study_index': widget.study_index,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('스터디에 성공적으로 참여했습니다!')));
      } else if (response.statusCode == 409) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('이미 참여 중인 스터디입니다.')));
      } else {
        print('스터디 참여 실패: ${response.body}');
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('스터디 참여에 실패했습니다.')));
      }
    } catch (e) {
      print('스터디 참여 요청 중 오류 발생: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('네트워크 오류가 발생했습니다.')));
    } finally {
      setState(() {
        _isJoining = false; // 로딩 종료
      });
    }
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
        title: Text('게시글 상세', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 30.0),
                child: Icon(Icons.school, size: 80, color: Colors.blue),
              ),
            ),
            Row(
              // 새로 추가된 Row 위젯
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ),
                SizedBox(width: 10),
                ElevatedButton.icon(
                  // 새로 추가된 참여하기 버튼
                  onPressed: _isJoining
                      ? null
                      : _joinStudy, // _isJoining이 true면 버튼 비활성화
                  icon:
                      _isJoining // 로딩 중일 때 로딩 인디케이터 표시
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Icon(Icons.person_add), // 평소 아이콘
                  label: Text(
                    _isJoining ? '참여 중...' : '참여하기',
                  ), // 로딩 중일 때 텍스트 변경
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(widget.author, style: TextStyle(color: Colors.grey)),
            SizedBox(height: 12),
            Text(widget.description),
            SizedBox(height: 20),
            Text(widget.description_more),
            Divider(),

            // 댓글 리스트
            Expanded(
              child: ListView.builder(
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final comment = comments[index];
                  return ListTile(
                    leading: Icon(Icons.account_circle, size: 30),
                    title: Text(comment['author'] ?? '익명'),
                    subtitle: Text(comment['text'] ?? ''),
                    trailing: Text(
                      // _formatCommentTime 함수를 사용하여 시간 표시
                      _formatCommentTime(comment['time'] as String?),
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  );
                },
              ),
            ),

            // 댓글 입력창
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
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
                  onPressed: _sendComment,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
