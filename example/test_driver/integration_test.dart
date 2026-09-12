import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test_driver.dart';
import 'package:path/path.dart' as p;
import 'package:puppeteer/puppeteer.dart' as puppeteer;

/// Drives the web integration test suite.
///
/// `flutter drive` always creates its own WebDriver (chromedriver) session to
/// launch and control the browser, even with `-d web-server`, and that
/// session's browser is picked at random (`--remote-debugging-port=0`) with
/// no flag to fix it in advance. So instead of launching a second, unrelated
/// browser, this reads the session chromedriver already created for
/// `flutter drive` back out of chromedriver's own session list, to attach a
/// second, independent Chrome DevTools Protocol connection to that same
/// Chrome instance. That connection is used only to intercept the browser's
/// native file-chooser dialog and answer it with a fixture file, since
/// `web_file_input_session.dart` detaches its hidden `<input type=file>` from
/// the DOM immediately after clicking it, which rules out a WebDriver
/// `sendKeys`-on-the-input approach.
Future<void> main() async {
  final fixturePath = p.join(
    Directory.current.path,
    'integration_test',
    'fixtures',
    'sample.txt',
  );
  final webPort = Platform.environment['WEB_PORT'] ?? '7357';
  final chromedriverPort = Platform.environment['CHROMEDRIVER_PORT'] ?? '4444';

  final debuggerAddress = await _waitForChromeDriverSession(chromedriverPort);
  final browser = await puppeteer.puppeteer.connect(
    browserUrl: 'http://$debuggerAddress',
  );

  // `integrationDriver()` below is what actually points the chromedriver
  // session's browser at the served app (there is no `Navigate` command
  // before it runs), so the app's page does not exist yet at this point.
  // Arming interception has to happen concurrently with, not before,
  // `integrationDriver()`.
  unawaited(_armFileChooserInterception(browser, webPort, fixturePath));

  await integrationDriver();
}

Future<void> _armFileChooserInterception(
  puppeteer.Browser browser,
  String webPort,
  String fixturePath,
) async {
  final page = await _findAppPage(browser, webPort);

  // Chrome only opens a file chooser for an <input type=file>.click() made
  // with "user activation": a real, trusted input event on the page.
  // Flutter's own tester.tap() is a framework-internal simulated gesture, not
  // a trusted browser event, so it does not carry activation by itself. A
  // real, CDP-dispatched click anywhere on the page establishes transient
  // activation for the whole frame, but that expires after a few seconds, and
  // how long the app takes to become interactive varies a lot with the
  // machine (a single upfront click was enough locally but had already
  // expired by the time the widget test's tap landed in CI), so this keeps
  // renewing it for the lifetime of the run instead of clicking only once.
  unawaited(_keepUserActivationAlive(page));

  await _autoAcceptFileChoosers(page, fixturePath);
}

Future<void> _keepUserActivationAlive(puppeteer.Page page) async {
  while (true) {
    await page.mouse.click(puppeteer.Point(1, 1));
    await Future<void>.delayed(const Duration(seconds: 2));
  }
}

/// Polls chromedriver's session list for the session `flutter drive` created,
/// and returns its Chrome DevTools Protocol address (`host:port`).
///
/// Uses chromedriver's `GET /sessions` endpoint, which predates the W3C
/// WebDriver spec but every chromedriver release still serves for
/// compatibility; it is the only way to read back a session neither started
/// nor otherwise addressable by this script.
Future<String> _waitForChromeDriverSession(String chromedriverPort) async {
  final sessionsUrl = Uri.parse('http://localhost:$chromedriverPort/sessions');
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final response = await http.get(sessionsUrl);
    final sessions = (jsonDecode(response.body) as Map)['value'] as List;
    for (final session in sessions) {
      final capabilities = (session as Map)['capabilities'] as Map;
      final chromeOptions =
          capabilities['goog:chromeOptions'] as Map<String, dynamic>?;
      final debuggerAddress = chromeOptions?['debuggerAddress'] as String?;
      if (debuggerAddress != null) return debuggerAddress;
    }
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  throw StateError(
    'No chromedriver session with a debuggerAddress appeared on '
    'localhost:$chromedriverPort within the deadline.',
  );
}

/// The browser chromedriver launches may still be on `about:blank` for a
/// moment, so this retries briefly rather than assuming the first page found
/// is already showing the served app.
Future<puppeteer.Page> _findAppPage(
  puppeteer.Browser browser,
  String webPort,
) async {
  final deadline = DateTime.now().add(const Duration(seconds: 30));
  while (DateTime.now().isBefore(deadline)) {
    final pages = await browser.pages;
    for (final page in pages) {
      if (page.url?.contains('localhost:$webPort') ?? false) {
        return page;
      }
    }
    await Future<void>.delayed(const Duration(milliseconds: 500));
  }
  throw StateError(
    'No page navigated to localhost:$webPort within the deadline.',
  );
}

/// Answers every file chooser opened during the run with [fixturePath].
///
/// Runs for the lifetime of the test rather than a single request, so it
/// does not matter whether this starts before or after the widget test's tap
/// reaches the browser.
Future<void> _autoAcceptFileChoosers(
  puppeteer.Page page,
  String fixturePath,
) async {
  while (true) {
    final chooser = await page.waitForFileChooser();
    await chooser.accept([File(fixturePath)]);
  }
}
