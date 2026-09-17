import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/llm_service.dart';

/// llama.cpp / Qwen 等严格 Jinja 模板只接受「恰好一条、且位于第一条」的
/// system 消息，历史之后的 system（Post-History Instructions / Author's Note /
/// 深度注入）会让服务端直接返回 HTTP 500
/// `Jinja Exception: System message must be at the beginning.`
///
/// 这些用例锁定本地/局域网端点的兼容降级行为，并确保云端端点不受影响。
void main() {
  const rearSystemChat = [
    {'role': 'system', 'content': 'You are Aqua.'},
    {'role': 'user', 'content': 'Tell me a story.'},
    {'role': 'assistant', 'content': 'Once upon a time'},
    {'role': 'system', 'content': '[System note: stay in character.]'},
  ];

  test('local LAN endpoint demotes the rear system message to user', () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);

    await service.generateWithReasoning(
      rearSystemChat,
      _config('http://10.0.0.244:9931/v1'),
    );

    expect(_messages(adapter.lastOptions), [
      {'role': 'system', 'content': 'You are Aqua.'},
      {'role': 'user', 'content': 'Tell me a story.'},
      {'role': 'assistant', 'content': 'Once upon a time'},
      {'role': 'user', 'content': '[System note: stay in character.]'},
    ]);
  });

  test('only the first of several leading system messages stays a system',
      () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);

    await service.generateWithReasoning(
      const [
        {'role': 'system', 'content': 'First.'},
        {'role': 'system', 'content': 'Second.'},
        {'role': 'user', 'content': 'hi'},
      ],
      _config('http://127.0.0.1:8080/v1'),
    );

    expect(_messages(adapter.lastOptions), [
      {'role': 'system', 'content': 'First.'},
      {'role': 'user', 'content': 'Second.'},
      {'role': 'user', 'content': 'hi'},
    ]);
  });

  test('cloud endpoints keep rear system messages untouched', () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);

    await service.generateWithReasoning(
      rearSystemChat,
      _config('https://api.deepseek.com'),
    );

    expect(_messages(adapter.lastOptions), rearSystemChat);
  });

  test('local endpoint without rear system messages is left untouched',
      () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);
    const clean = [
      {'role': 'system', 'content': 'You are Aqua.'},
      {'role': 'user', 'content': 'hi'},
    ];

    await service.generateWithReasoning(
      clean,
      _config('http://192.168.1.7:9931/v1'),
    );

    expect(_messages(adapter.lastOptions), clean);
  });
}

LLMConfig _config(String apiUrl) {
  return LLMConfig(
    provider: LLMProvider.openAICompatible,
    model: 'local-model',
    apiKey: 'test-key',
    apiUrl: apiUrl,
  );
}

List<dynamic> _messages(RequestOptions? options) {
  final data = options?.data as Map<String, dynamic>;
  return data['messages'] as List<dynamic>;
}

class _RecordingLlmAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({
        'choices': [
          {
            'message': {'content': 'ok'},
          },
        ],
      }),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
