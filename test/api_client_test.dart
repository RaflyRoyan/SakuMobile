import 'package:flutter_test/flutter_test.dart';
import 'package:saku_mobile/api/api_client.dart';

import 'fake_server.dart';

void main() {
  test('login stores the cookie and replays it with the CSRF header', () async {
    final server = FakeServer();
    final api = server.api();

    final user = await api.login('ryn', 'rahasia123');
    expect(user.nama, 'Ryn');
    expect(await api.client.tokenStore.read(), 'jwt-abc');

    final dash = await api.dashboard();
    expect(dash.ringkasan!.totalSaldoAkhir, 6389500);

    final last = server.requests.last;
    expect(last.headers['Cookie'], 'saku_token=jwt-abc');
    expect(last.headers['X-Requested-With'], 'saku');
  });

  test('ProblemDetails become ApiException with Indonesian title', () async {
    final api = FakeServer().api();
    await expectLater(
      api.login('ryn', 'salah'),
      throwsA(isA<ApiException>().having((e) => e.status, 'status', 401).having((e) => e.title, 'title', 'Username atau password salah.')),
    );
  });

  test('401 on an authenticated call clears the token and fires onUnauthorized', () async {
    final api = FakeServer().api();
    await api.client.tokenStore.write('kedaluwarsa');
    var fired = false;
    api.client.onUnauthorized = () => fired = true;

    await expectLater(api.me(), throwsA(isA<ApiException>()));
    expect(fired, isTrue);
    expect(await api.client.hasToken(), isFalse);
  });

  test('logout clears the stored cookie', () async {
    final api = FakeServer().api();
    await api.login('ryn', 'rahasia123');
    await api.logout();
    expect(await api.client.hasToken(), isFalse);
  });

  test('periodeAktif returns the active period', () async {
    final server = FakeServer();
    final api = server.api();
    await api.login('ryn', 'rahasia123');
    expect(await api.periodeAktif(), isNotNull);
  });
}
