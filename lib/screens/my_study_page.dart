import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_application_start/screens/room_page.dart';
import 'package:flutter_application_start/screens/home_page.dart'; // currentUserName이 정의된 파일
import 'package:flutter_application_start/models/study.dart'; // 새로 import된 Study 모델

class MyStudyPage extends StatefulWidget {
  // StatelessWidget -> StatefulWidget 변경
  @override
  _MyStudyPageState createState() => _MyStudyPageState();
}

class _MyStudyPageState extends State<MyStudyPage> {
  late Future<List<Study>> _joinedStudiesFuture; // 새로 추가된 Future 변수

  @override
  void initState() {
    super.initState();
    _joinedStudiesFuture = _fetchJoinedStudies(); // initState에서 데이터 로드 시작
  }

  // 새로 추가된 스터디 목록을 백엔드에서 가져오는 함수
  Future<List<Study>> _fetchJoinedStudies() async {
    final userName = currentUserName;
    if (userName == null || userName.isEmpty) {
      print('사용자가 로그인되지 않았습니다. 참여 스터디를 가져올 수 없습니다.');
      return [];
    }

    final url = Uri.parse(
      'http://127.0.0.1:8000/user/$userName/joined-studies',
    );
    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(utf8.decode(response.bodyBytes));
        // Study.fromJson을 사용하여 Map을 Study 객체로 변환
        return data.map((json) => Study.fromJson(json)).toList();
      } else {
        print('참여 스터디 불러오기 실패: ${response.statusCode} ${response.body}');
        throw Exception('참여 스터디를 불러오는 데 실패했습니다.');
      }
    } catch (e) {
      print('참여 스터디 네트워크 오류: $e');
      throw Exception('네트워크 오류로 참여 스터디를 불러올 수 없습니다.');
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
        title: Text('내 스터디', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<List<Study>>(
          // FutureBuilder로 감싸서 비동기 데이터 처리
          future: _joinedStudiesFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator()); // 로딩 중
            } else if (snapshot.hasError) {
              return Center(
                child: Text(
                  '${snapshot.error}', // 에러 발생 시 메시지 표시
                  textAlign: TextAlign.center,
                ),
              );
            } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
              return Center(child: Text('아직 참여한 스터디가 없습니다.')); // 데이터 없을 시 메시지
            } else {
              final joinedStudies = snapshot.data!; // 데이터가 있으면 가져와서 사용
              return GridView.builder(
                itemCount: joinedStudies.length,
                gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 0.9,
                ),
                itemBuilder: (context, index) {
                  final study = joinedStudies[index]; // Study 객체 사용
                  return GestureDetector(
                    onTap: () async {
                      // 스터디 상세 정보 요청
                      final url = Uri.parse(
                        'http://127.0.0.1:8000/study/${study.index}',
                      );
                      final chatUrl = Uri.parse(
                        'http://127.0.0.1:8000/chat/${study.index}/logs',
                      );

                      try {
                        final response = await http.get(url);
                        final chatResponse = await http.get(chatUrl);

                        if (response.statusCode == 200 &&
                            chatResponse.statusCode == 200) {
                          final studyData = json.decode(
                            utf8.decode(response.bodyBytes),
                          );
                          final chatLogs = json.decode(
                            utf8.decode(chatResponse.bodyBytes),
                          );

                          final membersStudyTime = Map<String, int>.from(
                            studyData['members_study_time'],
                          );

                          final messages = (chatLogs['logs'] as List).map((
                            msg,
                          ) {
                            return {
                              'text': msg,
                              'isMe': msg.toString().startsWith(
                                "[$currentUserName]",
                              ),
                            };
                          }).toList();

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => StudyRoomPage(
                                title: study.title,
                                study_index: study.index,
                                initialMembersStudyTime: membersStudyTime,
                                initialMessages: messages, // 💬 추가
                              ),
                            ),
                          );
                        } else {
                          print('스터디 데이터 또는 채팅 기록 불러오기 실패');
                        }
                      } catch (e) {
                        print('네트워크 오류: $e');
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.blue[50],
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black12, blurRadius: 4),
                        ],
                      ),
                      padding: EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.school, size: 40, color: Colors.blue),
                          SizedBox(height: 8),
                          Text(
                            study.title, // study.title로 변경
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            study.description, // study.description으로 변경
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            }
          },
        ),
      ),
    );
  }
}

// class MyStudyPage extends StatefulWidget {
//   // 임시 참여 스터디 데이터
//   // final List<Map<String, dynamic>> myStudies = [
//   //   {
//   //     'title': '일본어 스터디',
//   //     'desc': '매일 오전 7시 줌 스터디',
//   //     'detail': '일본어 자격증 따자!',
//   //     'comments': ['저도 참여하고 싶어요!', '매일 출석 가능해요!'],
//   //   },
//   //   {
//   //     'title': 'TOEIC 스터디',
//   //     'desc': '700점 이상 목표!',
//   //     'detail': '한 달 동안 집중!',
//   //     'comments': ['같이 화이팅!', '자료 공유 가능할까요?'],
//   //   },
//   //   {
//   //     'title': '코딩테스트 준비',
//   //     'desc': '백준 골드 도전',
//   //     'detail': '1일 1문제!',
//   //     'comments': ['나 알고리즘 약해요 ㅠ', '함께 공부해요!'],
//   //   },
//   // ];

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         iconTheme: IconThemeData(color: Colors.white),
//         leading: IconButton(
//           icon: Icon(Icons.arrow_back),
//           onPressed: () => Navigator.pop(context),
//         ),
//         centerTitle: true,
//         title: Text('게시글 확인', style: TextStyle(color: Colors.white)),
//         backgroundColor: Colors.blue,
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: GridView.builder(
//           itemCount: myStudies.length,
//           gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
//             maxCrossAxisExtent: 220, // 카드 최대 너비
//             crossAxisSpacing: 16,
//             mainAxisSpacing: 16,
//             childAspectRatio: 0.9, // 비율 조정 (내용에 따라)
//           ),
//           itemBuilder: (context, index) {
//             final study = myStudies[index];
//             return GestureDetector(
//               onTap: () {
//                 Navigator.push(
//                   context,
//                   MaterialPageRoute(
//                     builder: (_) => StudyRoomPage(
//                       title: study['title'],
//                       study_index: index, // study_index 전달
//                       initialMembersStudyTime: {}, // 임시로 빈 Map 전달
//                     ),
//                   ),
//                 );
//               },
//               child: Container(
//                 decoration: BoxDecoration(
//                   color: Colors.blue[50],
//                   borderRadius: BorderRadius.circular(16),
//                   boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
//                 ),
//                 padding: EdgeInsets.all(12),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Icon(Icons.school, size: 40, color: Colors.blue),
//                     SizedBox(height: 8),
//                     Text(
//                       study['title'],
//                       style: TextStyle(
//                         fontWeight: FontWeight.bold,
//                         fontSize: 16,
//                       ),
//                     ),
//                     SizedBox(height: 4),
//                     Text(
//                       study['desc'],
//                       maxLines: 2,
//                       overflow: TextOverflow.ellipsis,
//                       style: TextStyle(fontSize: 13, color: Colors.grey[700]),
//                     ),
//                   ],
//                 ),
//               ),
//             );
//           },
//         ),
//       ),
//     );
//   }
// }
