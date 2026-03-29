import 'package:flutter/material.dart';

class DiseaseDetail extends StatelessWidget {
  const DiseaseDetail({super.key, required this.disease});

  final String disease;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(disease)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.asset('assets/covid.jpg', height: 200),
            const SizedBox(height: 16),
            Text(disease, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Vui lòng tham khảo ý kiến bác sĩ để được chẩn đoán chính xác.'),
          ],
        ),
      ),
    );
  }
}
