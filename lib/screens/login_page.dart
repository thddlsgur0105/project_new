import 'package:flutter/material.dart';
// import 'home_page.dart';
import 'package:flutter_application_start/screens/home_page.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

Future<bool> login(String email, String password) async {
  final url = Uri.parse('http://127.0.0.1:8000/login');
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );

  if (response.statusCode == 200) {
    print('로그인 성공: ${response.body}');
    final Map<String, dynamic> responseData = jsonDecode(response.body);
    final String userName = responseData['name']; // 서버 응답에서 사용자 이름 가져오기

    // SharedPreferences에 로그인 정보 저장
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setString('userName', userName);

    // 전역 변수 업데이트
    isLoggedIn = true;
    currentUserName = userName;

    return true;
  } else {
    print('로그인 실패: ${response.body}');
    return false;
  }
}

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: Text('로그인', style: TextStyle(color: Colors.black)),
        centerTitle: true,
        iconTheme: IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ListView(
          children: [
            SizedBox(height: 32),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: obscurePassword,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffix: GestureDetector(
                  onTap: () {
                    setState(() {
                      obscurePassword = !obscurePassword;
                    });
                  },
                  child: Text(
                    obscurePassword ? '보기' : '숨기기',
                    style: TextStyle(color: Colors.blue),
                  ),
                ),
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final email = emailController.text;
                final password = passwordController.text;

                final success = await login(email, password);
                if (success) {
                  // 성공 메시지 표시 (옵션)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('로그인 성공! ${currentUserName ?? "환영합니다"}님!'),
                    ),
                  );

                  // HomePage로 이동하면서 이전 화면 스택 제거
                  // HomePage에서 initState()에 로그인 상태 확인 로직이 있으므로,
                  // 이 로직이 자동으로 로그인 상태를 업데이트하고 UI를 다시 그릴 것입니다.
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => HomePage()),
                  );
                } else {
                  // 로그인 실패 시 다이얼로그 표시
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('로그인 실패'),
                      content: Text('이메일 또는 비밀번호가 올바르지 않습니다.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('확인'),
                        ),
                      ],
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
              child: Text('로그인'),
            ),

            SizedBox(height: 12),
            TextButton(
              onPressed: () {
                // 비밀번호 찾기 로직을 위한 네비게이션 또는 다이얼로그 추가
                // 예: Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordPage()));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('비밀번호 찾기 기능은 아직 구현되지 않았습니다.')),
                );
              },
              child: Text('비밀번호를 잊으셨나요?', style: TextStyle(color: Colors.blue)),
            ),
          ],
        ),
      ),
    );
  }
}
