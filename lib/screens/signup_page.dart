import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

Future<bool> signup(String email, String password, String name) async {
  final url = Uri.parse('http://127.0.0.1:8000/signup'); // 실제 배포 시 서버 IP/도메인 사용
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password, 'name': name}),
  );

  if (response.statusCode == 200) {
    return true;
  } else {
    return false;
  }
}

class SignupPage extends StatelessWidget {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    bool isChecked = false;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        leading: IconButton(
          icon: Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('회원 가입', style: TextStyle(color: Colors.black)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: ListView(
          children: [
            SizedBox(height: 32),
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: '이름',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '비밀번호',
                suffixText: '보기',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 12),
            Row(
              children: [
                StatefulBuilder(
                  builder: (context, setState) => Checkbox(
                    value: isChecked,
                    onChanged: (value) {
                      setState(() => isChecked = value!);
                    },
                  ),
                ),
                Expanded(child: Text('뉴스레터 및 기타 홍보 정보 수신에 동의합니다.')),
              ],
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                final name = nameController.text.trim();
                final email = emailController.text.trim();
                final password = passwordController.text.trim();

                final success = await signup(email, password, name);
                if (success) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('회원가입 성공!')));
                  Navigator.pop(context); // 회원가입 후 이전 화면으로 이동
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('회원가입 실패. 다시 시도해주세요.')),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue,
                foregroundColor: Colors.white,
                minimumSize: Size(double.infinity, 48),
              ),
              child: Text('회원 가입'),
            ),
            SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
