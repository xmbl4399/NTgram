import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:native_tavern/domain/services/llm_service.dart';

/// Post-History Instructions 以及按深度注入的 Author's Note / World Info
/// **一律保持 system 角色**发送（2026-09-18 起）。
///
/// 背景：这里曾按端点自动降级 —— 本地/局域网端点把首条之后的 system 改写为
/// user，以绕过 Qwen / llama.cpp 严格 Jinja 模板的
/// `raise_exception('System message must be at the beginning.')`（否则 500）。
///
/// 但降级有两个副作用：
///   1. 「历史后指令」与上一条用户发言**角色相同且相邻**，模型会把提示词
///      误当成用户又说了句话；
///   2. 部分角色卡要求 system 级 jailbreak 才生效，降级后形同失效。
///
/// 为兼容大多数角色卡，改为全端点统一保持 system 角色。严格模板端点需自行
/// 放宽模板（见 README「本地模型」小节）。
void main() {
  const rearSystemChat = [
    {'role': 'system', 'content': 'You are Aqua.'},
    {'role': 'user', 'content': 'Tell me a story.'},
    {'role': 'assistant', 'content': 'Once upon a time'},
    {'role': 'system', 'content': '[System note: stay in character.]'},
  ];

  test('local LAN endpoint keeps the rear system message as system', () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);

    await service.generateWithReasoning(
      rearSystemChat,
      _config('http://10.0.0.244:9931/v1'),
    );

    expect(_messages(adapter.lastOptions), rearSystemChat);
  });

  test('loopback endpoint keeps rear system messages as system', () async {
    final adapter = _RecordingLlmAdapter();
    final service = LLMService(dio: Dio()..httpClientAdapter = adapter);
    const messages = [
      {'role': 'system', 'content': 'First.'},
      {'role': 'system', 'content': 'Second.'},
      {'role': 'user', 'content': 'hi'},
    ];

    await service.generateWithReasoning(
      messages,
      _config('http://127.0.0.1:8080/v1'),
    );

    expect(_messages(adapter.lastOptions), messages);
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

  test('callers keep their own message list free of mutation', () async {
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
