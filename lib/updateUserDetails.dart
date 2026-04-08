import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class UpdateUserDetails extends StatefulWidget {
  const UpdateUserDetails({
    super.key,
    required this.label,
    required this.field,
  });

  final String label;
  final String field;

  @override
  State<UpdateUserDetails> createState() => _UpdateUserDetailsState();
}

class _UpdateUserDetailsState extends State<UpdateUserDetails> {
  final TextEditingController _textController = TextEditingController();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isLoading = false;

  TextInputType _keyboardType() {
    if (widget.field == 'phone') {
      return TextInputType.phone;
    }
    if (widget.field == 'address') {
      return TextInputType.streetAddress;
    }
    return TextInputType.text;
  }

  int _maxLines() {
    return widget.field == 'address' ? 3 : 1;
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _updateData() async {
    final user = _auth.currentUser;
    if (user == null) {
      return;
    }

    final value = _textController.text.trim();
    if (value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Vui lòng nhập ${widget.label}')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {widget.field: value},
        SetOptions(merge: true),
      );
      if (!mounted) {
        return;
      }
      Navigator.pop(context);
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.label),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
        child: Column(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: user == null
                  ? null
                  : FirebaseFirestore.instance.collection('users').doc(user.uid).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final currentValue = data?[widget.field]?.toString() ?? '';

                if (_textController.text.isEmpty && currentValue.isNotEmpty) {
                  _textController.text = currentValue;
                }

                return TextFormField(
                  controller: _textController,
                  textInputAction: TextInputAction.done,
                  keyboardType: _keyboardType(),
                  maxLines: _maxLines(),
                  decoration: InputDecoration(
                    hintText: widget.label,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _updateData,
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Cập nhật'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
