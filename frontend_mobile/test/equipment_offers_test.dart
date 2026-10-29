import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:smart_sports_hub/providers/auth_provider.dart';
import 'package:smart_sports_hub/screens/equipment_screen.dart';
import 'package:smart_sports_hub/screens/promo_codes_screen.dart';
import 'package:smart_sports_hub/screens/venue_details_screen.dart';
import 'package:smart_sports_hub/services/api_service.dart';
import 'package:smart_sports_hub/providers/theme_provider.dart';
import 'package:smart_sports_hub/screens/rental_shop_screen.dart';

class _Auth extends AuthProvider {
  @override
  Map<String, dynamic> get user => {'id': 1, 'role': 'CUSTOMER'};
}

class _Api implements HttpClientAdapter {
  bool fail = false;
  bool failRentals = false;
  bool free = false;
  bool mixedItems = false;
  bool conflict = false;
  bool unavailable = false;
  bool reserved = false;
  final requests = <RequestOptions>[];
  Map<String, dynamic> get item => {
        'id': 2,
        'name': 'Padel racket',
        'sport': {'name': 'Padel'},
        'venue': {'name': 'Court A'},
        'brand': 'Sample Brand',
        'model': 'Control',
        'material': 'Fibreglass',
        'ballType': 'Padel ball',
        'condition': 'Good',
        'pricePerSlot': free ? 0 : 25,
        'quantity': 2,
        'availableQuantity': unavailable ? 0 : 2,
        'isActive': true
      };
  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requests.add(options);
    dynamic data = [];
    if (options.path == '/equipment') {
      data = [
        item,
        if (mixedItems)
          {
            ...item,
            'id': 3,
            'name': 'Cricket bat',
            'sport': {'name': 'Cricket'},
            'venue': null
          }
      ];
    }
    if (options.path == '/equipment/2/rent') {
      reserved = true;
      data = {'id': 8, 'totalPrice': free ? 0 : 25, 'paymentId': 9};
    }
    if (options.path == '/equipment/my-rentals') {
      final day = DateTime.now()
          .toUtc()
          .add(const Duration(days: 2, hours: 5))
          .toIso8601String()
          .substring(0, 10);
      data = [
        for (final status in [
          'PENDING_PAYMENT',
          'CONFIRMED',
          'RETURNED',
          'CANCELLED'
        ])
          {
            'id': status == 'PENDING_PAYMENT' ? 1 : 2,
            'equipment': item,
            'quantity': 1,
            'rentalDate': day,
            'returnDate': day,
            'totalPrice': 25,
            'status': status,
            'payment': {
              'id': 9,
              'status': status == 'PENDING_PAYMENT' ? 'PENDING' : 'PAID',
              'expiresAt': DateTime.now()
                  .toUtc()
                  .add(const Duration(minutes: 20))
                  .toIso8601String()
            },
          }
      ];
    }
    if (options.path == '/venues/1') {
      data = {
        'id': 1,
        'name': 'Court A',
        'sport': {'name': 'Padel'},
        'pricePerSlot': 2000,
        'openingTime': '06:00',
        'closingTime': '23:00',
        'equipment': [item]
      };
    }
    if (options.path == '/promo') {
      data = [
        {
          'code': 'PLAY20',
          'discountType': 'PERCENTAGE',
          'discountValue': 20,
          'perCustomerLimit': 1,
          'remainingUses': 0,
          'available': false
        }
      ];
    }
    return ResponseBody.fromString(
        jsonEncode(fail ||
                failRentals && options.path == '/equipment/my-rentals' ||
                conflict && options.method == 'POST'
            ? {'message': 'Service unavailable'}
            : {'success': true, 'data': data}),
        fail ||
                failRentals && options.path == '/equipment/my-rentals' ||
                conflict && options.method == 'POST'
            ? 503
            : 200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final boundaryKey = GlobalKey();
  setUpAll(() async {
    final configFile = File('.dart_tool/package_config.json');
    final packages =
        jsonDecode(configFile.readAsStringSync())['packages'] as List;
    final root = configFile.uri.resolve(
        '${packages.firstWhere((p) => p['name'] == 'flutter')['rootUri']}/');
    for (final entry in {
      'roboto-regular.ttf': 'Roboto',
      'roboto-bold.ttf': 'Roboto',
      'materialicons-regular.otf': 'MaterialIcons'
    }.entries) {
      final font = File.fromUri(root
          .resolve('../../bin/cache/artifacts/material_fonts/${entry.key}'));
      await (FontLoader(entry.value)
            ..addFont(
                Future.value(ByteData.sublistView(font.readAsBytesSync()))))
          .load();
    }
  });
  late _Api api;
  late _Auth auth;
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _Api();
    ApiService().dio.httpClientAdapter = api;
    ApiService().socket.disconnect();
    auth = _Auth();
  });
  tearDown(() => auth.dispose());
  Future<void> mount(WidgetTester tester, Widget screen,
      {Brightness brightness = Brightness.light,
      double width = 390,
      double scale = 1}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeProvider.lightTheme,
                darkTheme: ThemeProvider.darkTheme,
                themeMode: brightness == Brightness.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: screen))));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('RENDER_RENTALS')) return;
    await tester.runAsync(() async {
      await precacheImage(
          const ResizeImage(AssetImage('assets/gear/padel-racket.png'),
              width: 650),
          boundaryKey.currentContext!);
    });
    await tester.pumpAndSettle();
    await tester.runAsync(() async {
      final boundary = boundaryKey.currentContext!.findRenderObject()!
          as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('../design-concepts/rentals/implementation/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
      'venue menu displays staff-supplied specifications and rental navigation',
      (tester) async {
    await mount(tester, const VenueDetailsScreen(venueId: 1));
    expect(find.text('Ball type: Padel ball'), findsOneWidget);
    expect(find.text('Material / surface: Fibreglass'), findsOneWidget);
    await tester.tap(find.text('Reserve venue equipment'));
    await tester.pumpAndSettle();
    expect(
        api.requests.any(
            (r) => r.path == '/equipment' && r.queryParameters['venueId'] == 1),
        isTrue);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'rental quantity preview is priced and request dates are explicit',
      (tester) async {
    await mount(tester, const EquipmentScreen());
    await tester.ensureVisible(find.text('View gear'));
    await tester.tap(find.text('View gear'));
    await tester.pumpAndSettle();
    expect(find.text('Total: PKR 25'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '2');
    await tester.pumpAndSettle();
    expect(find.text('Total: PKR 50'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField), '3');
    await tester.tap(find.text('Reserve & continue to payment'));
    await tester.pumpAndSettle();
    expect(find.text('Enter an available quantity'), findsOneWidget);
    expect(api.requests.where((r) => r.method == 'POST'), isEmpty);
    expect(tester.takeException(), isNull);
  });
  testWidgets('offers explain customer allowance and unavailable state',
      (tester) async {
    await mount(tester, const PromoCodesScreen());
    expect(find.text('PLAY20'), findsOneWidget);
    expect(find.text('1 uses per customer · 0 remaining'), findsOneWidget);
    expect(find.text('Allowance used or offer unavailable'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('equipment failure offers retry and recovers without signing out',
      (tester) async {
    api.fail = true;
    await mount(tester, const EquipmentScreen());
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    api.fail = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Padel racket'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('rental flow renders in ${brightness.name}', (tester) async {
      await mount(tester, const EquipmentScreen(), brightness: brightness);
      await capture(tester, 'browse-${brightness.name}');
      await tester.ensureVisible(find.text('View gear'));
      await tester.tap(find.text('View gear'));
      await tester.pumpAndSettle();
      await capture(tester, 'details-${brightness.name}');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('My rentals'));
      await tester.pumpAndSettle();
      expect(find.text('Awaiting payment'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      await capture(tester, 'my-rentals-${brightness.name}');
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.text('Returned'), findsOneWidget);
      expect(find.text('Cancelled'), findsOneWidget);
      expect(find.text('Continue payment'), findsNothing);
      expect(find.text('Record return'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('rental history failure does not block browsing', (tester) async {
    api.failRentals = true;
    await mount(tester, const EquipmentScreen());
    expect(find.text('Padel racket'), findsOneWidget);
    await tester.tap(find.text('My rentals'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh), findsOneWidget);
    api.failRentals = false;
    await tester.tap(find.byIcon(Icons.refresh));
    await tester.pumpAndSettle();
    expect(find.text('Awaiting payment'), findsOneWidget);
  });
  testWidgets('sport and venue filters match visible inventory',
      (tester) async {
    api.mixedItems = true;
    await mount(tester, const EquipmentScreen());
    await tester.tap(find.text('Cricket'));
    await tester.pumpAndSettle();
    expect(find.text('Padel racket'), findsNothing);
    expect(find.text('Cricket bat'), findsOneWidget);
    await tester.tap(find.text('All sports'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('All venues'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Court A').last);
    await tester.pumpAndSettle();
    expect(find.text('Cricket bat'), findsNothing);
    expect(find.text('Padel racket'), findsOneWidget);
  });
  testWidgets(
      'multi-day free rental sends inclusive dates and only reserves once',
      (tester) async {
    api.free = true;
    final day = DateTime.now().toUtc().add(const Duration(days: 1, hours: 5));
    await mount(
        tester,
        RentalDetailsScreen(
            item: api.item,
            dates: DateTimeRange(
                start: day, end: day.add(const Duration(days: 2)))));
    await tester.tap(find.byTooltip('Increase quantity'));
    await tester.pumpAndSettle();
    final button = find.text('Reserve equipment');
    await tester.tap(button);
    await tester.tap(button, warnIfMissed: false);
    await tester.pumpAndSettle();
    final posts =
        api.requests.where((r) => r.path == '/equipment/2/rent').toList();
    expect(posts, hasLength(1));
    expect(posts.single.data['quantity'], 2);
    expect(posts.single.data['rentalDate'],
        day.toIso8601String().substring(0, 10));
    expect(posts.single.data['returnDate'],
        day.add(const Duration(days: 2)).toIso8601String().substring(0, 10));
    expect(api.requests.any((r) => r.path == '/payments/checkout'), isFalse);
  });
  testWidgets('stock conflict preserves details and refreshes availability',
      (tester) async {
    api.conflict = true;
    final day = DateTime.now();
    await mount(
        tester,
        RentalDetailsScreen(
            item: api.item, dates: DateTimeRange(start: day, end: day)));
    await tester.tap(find.text('Reserve & continue to payment'));
    await tester.pumpAndSettle();
    expect(find.text('Rental details'), findsOneWidget);
    expect(api.requests.where((r) => r.path == '/equipment').length,
        greaterThan(1));
    expect(tester.takeException(), isNull);
  });
  testWidgets('narrow large-text browse, details and history stay usable',
      (tester) async {
    await mount(tester, const EquipmentScreen(), width: 320, scale: 1.5);
    Finder listScroll() => find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first;
    await tester.scrollUntilVisible(find.text('View gear'), 200,
        scrollable: listScroll());
    await tester.pumpAndSettle();
    await tester.tap(find.text('View gear'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Total: PKR 25'), 200,
        scrollable: listScroll());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('My rentals'), -200,
        scrollable: listScroll());
    await tester.pumpAndSettle();
    await tester.tap(find.text('My rentals'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Continue payment'), 200,
        scrollable: listScroll());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
