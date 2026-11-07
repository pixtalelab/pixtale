import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:pixtale_sync/request/request.dart';

void main() {
  testWidgets('持续上传超过两分钟仍成功，结束后清理计时器', (tester) async {
    final body = StreamController<List<int>>();
    var aborted = false;
    final client = MockClient.streaming((request, stream) async {
      (request as http.Abortable).abortTrigger!.then((_) => aborted = true);
      await stream.drain<void>();
      return _response();
    });
    addTearDown(client.close);
    final result = expectLater(
      _upload(client, file: http.MultipartFile('file', body.stream, 3)),
      completion({'saved': true}),
    );
    await tester.pump();
    for (var i = 0; i < 3; i++) {
      await tester.pump(const Duration(minutes: 1));
      body.add([i]);
      await tester.pump();
    }
    unawaited(body.close());
    await tester.pump();
    await result;
    await tester.pump(const Duration(minutes: 4));
    expect(aborted, isFalse);
  });

  testWidgets('上传停滞两分钟取消当前请求，不关闭共享客户端', (tester) async {
    final body = StreamController<List<int>>();
    var aborted = false;
    var calls = 0;
    final client = MockClient.streaming((request, stream) async {
      calls++;
      if (calls > 1) {
        await stream.drain<void>();
        return _response();
      }
      final subscription = stream.listen((_) {});
      await (request as http.Abortable).abortTrigger;
      aborted = true;
      await subscription.cancel();
      throw http.RequestAbortedException(request.url);
    });
    addTearDown(client.close);
    final result = expectLater(
      _upload(client, file: http.MultipartFile('file', body.stream, 2)),
      throwsA(_uploadTimeout),
    );
    await tester.pump(const Duration(minutes: 1));
    body.add([1]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    expect(aborted, isFalse);
    await tester.pump(const Duration(minutes: 1));
    await result;
    expect(aborted, isTrue);
    unawaited(body.close());
    await expectLater(_upload(client), completion({'saved': true}));
  });

  testWidgets('连接未建立也受两分钟空闲超时限制', (tester) async {
    var aborted = false;
    final client = MockClient.streaming((request, stream) async {
      await (request as http.Abortable).abortTrigger;
      aborted = true;
      throw http.RequestAbortedException(request.url);
    });
    addTearDown(client.close);
    final result = expectLater(_upload(client), throwsA(_uploadTimeout));
    await tester.pump(const Duration(minutes: 2));
    await result;
    expect(aborted, isTrue);
  });

  testWidgets('客户端停止消费请求体时，文件仍有数据也会超时', (tester) async {
    final body = StreamController<List<int>>();
    var aborted = false;
    final client = MockClient.streaming((request, stream) async {
      final subscription = stream.listen((_) {});
      subscription.pause();
      await (request as http.Abortable).abortTrigger;
      aborted = true;
      unawaited(subscription.cancel());
      throw http.RequestAbortedException(request.url);
    });
    addTearDown(client.close);
    final result = expectLater(
      _upload(client, file: http.MultipartFile('file', body.stream, 2)),
      throwsA(_uploadTimeout),
    );
    await tester.pump(const Duration(minutes: 1));
    body.add([1]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await result;
    expect(aborted, isTrue);
    unawaited(body.close());
  });

  testWidgets('一个请求超时不影响另一个持续上传的请求', (tester) async {
    final body = StreamController<List<int>>();
    var aborted = 0;
    final client = MockClient.streaming((request, stream) async {
      final multipart = request as http.MultipartRequest;
      if (multipart.fields['albumId'] == 'stalled') {
        await (request as http.Abortable).abortTrigger;
        aborted++;
        throw http.RequestAbortedException(request.url);
      }
      (request as http.Abortable).abortTrigger!.then((_) => aborted++);
      await stream.drain<void>();
      return _response();
    });
    addTearDown(client.close);
    final stalled = expectLater(
      upload(
        '/api/photo/add',
        baseUrl: 'https://example.test',
        token: 'token',
        client: client,
        fields: {'albumId': 'stalled'},
        file: http.MultipartFile.fromBytes('file', [1]),
      ),
      throwsA(_uploadTimeout),
    );
    final active = expectLater(
      _upload(client, file: http.MultipartFile('file', body.stream, 2)),
      completion({'saved': true}),
    );
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    body.add([1]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    body.add([2]);
    unawaited(body.close());
    await tester.pump();
    await stalled;
    await active;
    expect(aborted, 1);
  });

  testWidgets('上传完成后等待响应超过两分钟会超时', (tester) async {
    var uploaded = false;
    final client = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      uploaded = true;
      await (request as http.Abortable).abortTrigger;
      throw http.RequestAbortedException(request.url);
    });
    addTearDown(client.close);
    final result = expectLater(_upload(client), throwsA(_uploadTimeout));
    await tester.pump();
    expect(uploaded, isTrue);
    await tester.pump(const Duration(minutes: 2));
    await result;
  });

  testWidgets('响应持续返回超过两分钟仍可完成', (tester) async {
    final body = StreamController<List<int>>();
    final client = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      return http.StreamedResponse(body.stream, 200);
    });
    addTearDown(client.close);
    final result = expectLater(_upload(client), completion({'saved': true}));
    await tester.pump();
    for (final text in ['{"code":200,', '"data":', '{"saved":true}}']) {
      await tester.pump(const Duration(minutes: 1));
      body.add(utf8.encode(text));
      await tester.pump();
    }
    unawaited(body.close());
    await tester.pump();
    await result;
  });

  testWidgets('响应流停滞会取消，空数据块不延长超时', (tester) async {
    final body = StreamController<List<int>>();
    var aborted = false;
    final client = MockClient.streaming((request, stream) async {
      await stream.drain<void>();
      (request as http.Abortable).abortTrigger!.then((_) {
        aborted = true;
        body.addError(http.RequestAbortedException(request.url));
        unawaited(body.close());
      });
      return http.StreamedResponse(body.stream, 200);
    });
    addTearDown(client.close);
    final result = expectLater(_upload(client), throwsA(_uploadTimeout));
    await tester.pump();
    body.add(utf8.encode('{"code":200,'));
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    body.add([]);
    await tester.pump();
    await tester.pump(const Duration(minutes: 1));
    await result;
    expect(aborted, isTrue);
  });

  testWidgets('网络失败立即返回并清理计时器', (tester) async {
    var aborted = false;
    final client = MockClient.streaming((request, stream) async {
      (request as http.Abortable).abortTrigger!.then((_) => aborted = true);
      throw http.ClientException('Disconnected');
    });
    addTearDown(client.close);
    await expectLater(
      _upload(client),
      throwsA(
        isA<ApiException>().having(
          (e) => e.message,
          'message',
          'Network error',
        ),
      ),
    );
    await tester.pump(const Duration(minutes: 4));
    expect(aborted, isFalse);
  });
}

final _uploadTimeout = isA<ApiException>().having(
  (error) => error.message,
  'message',
  'Upload timed out',
);

Future<dynamic> _upload(http.Client client, {http.MultipartFile? file}) =>
    upload(
      '/api/photo/add',
      baseUrl: 'https://example.test',
      token: 'token',
      client: client,
      fields: {'albumId': 'album'},
      file: file ?? http.MultipartFile.fromBytes('file', [1, 2, 3]),
    );

http.StreamedResponse _response() => http.StreamedResponse(
  Stream.value(utf8.encode('{"code":200,"data":{"saved":true}}')),
  200,
);
