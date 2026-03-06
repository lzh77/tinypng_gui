import 'package:flutter/material.dart';
import '../../../data/models/api_key_info.dart';

/// 新增 API Key 对话框
/// 包含别名和 Key 两个输入字段，提交时返回 [ApiKeyInfo]
class AddApiKeyDialog extends StatefulWidget {
  const AddApiKeyDialog({super.key});

  @override
  State<AddApiKeyDialog> createState() => _AddApiKeyDialogState();
}

class _AddApiKeyDialogState extends State<AddApiKeyDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();
  bool _isObscured = true;

  @override
  void dispose() {
    _aliasController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final ApiKeyInfo apiKey = ApiKeyInfo(
      key: _keyController.text.trim(),
      alias: _aliasController.text.trim(),
    );
    Navigator.of(context).pop(apiKey);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('添加 API Key'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 别名输入
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: '别名',
                  hintText: '例如：个人账号',
                  prefixIcon: Icon(Icons.label_outline),
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入别名';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              // API Key 输入
              TextFormField(
                controller: _keyController,
                obscureText: _isObscured,
                decoration: InputDecoration(
                  labelText: 'API Key',
                  hintText: '请输入 TinyPNG API Key',
                  prefixIcon: const Icon(Icons.key_outlined),
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _isObscured ? Icons.visibility_off : Icons.visibility,
                    ),
                    onPressed: () {
                      setState(() => _isObscured = !_isObscured);
                    },
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return '请输入 API Key';
                  }
                  if (value.trim().length < 10) {
                    return 'API Key 格式不正确';
                  }
                  return null;
                },
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 8),
              // 提示文字
              Text(
                '可在 https://tinypng.com/developers 获取 API Key',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.outline,
                    ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('添加'),
        ),
      ],
    );
  }
}
