import 'package:flutter/material.dart';

class Skip extends StatelessWidget {
  const Skip({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              const Spacer(),
              Image.asset('assets/Medic.ly_poster1.png', fit: BoxFit.contain),
              const SizedBox(height: 24),
              const Text(
                'Đặt lịch khám trực tuyến',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Đặt lịch nhanh và quản lý lịch hẹn dễ dàng.',
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
                  child: const Text('Bắt đầu'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
