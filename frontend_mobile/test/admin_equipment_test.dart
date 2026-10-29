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
import 'package:smart_sports_hub/providers/theme_provider.dart';
import 'package:smart_sports_hub/screens/equipment_screen.dart';
import 'package:smart_sports_hub/screens/admin_equipment_screen.dart';
import 'package:smart_sports_hub/services/api_service.dart';

class _Admin extends AuthProvider {
  @override
  Map<String, dynamic> get user => {'id': 1, 'role': 'ADMIN'};
}

class _Api implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  bool rejectSave = false, failRentals = false;
  Map<String, dynamic> item = {
    'id': 2,
    'name': 'Padel racket',
    'sportId': 1,
    'sport': {'id': 1, 'name': 'Padel'},
    'venueId': 1,
    'venue': {'id': 1, 'name': 'Court A'},
    'pricePerSlot': 500,
    'quantity': 12,
    'isActive': true,
    'brand': 'Sample brand',
    'condition': 'Good'
  };
  Map<String, dynamic> rental(String status, {int days = 0}) {
    final day = DateTime.now()
        .toUtc()
        .add(Duration(days: days, hours: 5))
        .toIso8601String()
        .substring(0, 10);
    return {
      'id': 8,
      'equipment': item,
      'user': {'id': 4, 'name': 'Sample player'},
      'quantity': 2,
      'rentalDate': day,
      'returnDate': day,
      'totalPrice': 1000,
      'status': status,
      'payment': {'status': 'PAID'}
    };
  }

  @override
  Future<ResponseBody> fetch(RequestOptions options, Stream<Uint8List>? stream,
      Future<void>? cancel) async {
    requests.add(options);
    dynamic data = [];
    int status = 200;
    String? error;
    if (options.path == '/equipment' && options.method == 'GET') {
      data = [
        item,
        {
          ...item,
          'id': 3,
          'name': 'Cricket bat',
          'sportId': 2,
          'sport': {'id': 2, 'name': 'Cricket'},
          'venueId': null,
          'venue': null,
          'isActive': false
        }
      ];
    }
    if (options.path == '/equipment/rentals/all') {
      data = [
        rental('CONFIRMED'),
        rental('PENDING_PAYMENT'),
        rental('RETURNED'),
        rental('CANCELLED')
      ];
      if (failRentals) {
        status = 503;
        error = 'Service unavailable';
      }
    }
    if (options.path == '/sports') {
      data = [
        {'id': 1, 'name': 'Padel'},
        {'id': 2, 'name': 'Cricket'}
      ];
    }
    if (options.path == '/venues') {
      data = [
        {'id': 1, 'name': 'Court A', 'sportId': 1},
        {'id': 2, 'name': 'Cricket ground', 'sportId': 2}
      ];
    }
    if (options.method == 'PUT' ||
        options.path == '/equipment' && options.method == 'POST') {
      if (rejectSave) {
        status = 409;
        error =
            'Finish or cancel active rentals before reducing or relocating inventory';
      } else {
        item = {...item, ...Map<String, dynamic>.from(options.data)};
        data = item;
      }
    }
    return ResponseBody.fromString(
        jsonEncode(error == null
            ? {'success': true, 'data': data}
            : {'message': error}),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Api api;
  late _Admin auth;
  final boundary = GlobalKey();
  setUpAll(() async {
    final config = File('.dart_tool/package_config.json');
    final packages = jsonDecode(config.readAsStringSync())['packages'] as List;
    final root = config.uri.resolve(
        '${packages.firstWhere((p) => p['name'] == 'flutter')['rootUri']}/');
    for (final entry in {
      'roboto-regular.ttf': 'Roboto',
      'roboto-bold.ttf': 'Roboto',
      'materialicons-regular.otf': 'MaterialIcons'
    }.entries) {
      final bytes = File.fromUri(root
              .resolve('../../bin/cache/artifacts/material_fonts/${entry.key}'))
          .readAsBytesSync();
      await (FontLoader(entry.value)
            ..addFont(Future.value(ByteData.sublistView(bytes))))
          .load();
    }
  });
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    api = _Api();
    auth = _Admin();
    ApiService().socket.disconnect();
    ApiService().dio.httpClientAdapter = api;
  });
  tearDown(() => auth.dispose());
  Future<void> mount(WidgetTester tester, Widget screen,
      {Brightness mode = Brightness.light,
      double width = 390,
      double scale = 1}) async {
    tester.view.physicalSize = Size(width, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(ChangeNotifierProvider<AuthProvider>.value(
        value: auth,
        child: RepaintBoundary(
            key: boundary,
            child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: ThemeProvider.lightTheme,
                darkTheme: ThemeProvider.darkTheme,
                themeMode:
                    mode == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: screen))));
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('RENDER_ADMIN_RENTALS')) return;
    await tester.runAsync(() async {
      final image = await (boundary.currentContext!.findRenderObject()!
              as RenderRepaintBoundary)
          .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file =
          File('../design-concepts/rentals/admin-implementation/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  Future<void> show(WidgetTester tester, Finder target) async {
    final scroll = find
        .byWidgetPredicate(
            (w) => w is Scrollable && w.axisDirection == AxisDirection.down)
        .first;
    await tester.scrollUntilVisible(target, 220, scrollable: scroll);
    await tester.pumpAndSettle();
  }

  for (final mode in Brightness.values) {
    testWidgets('admin inventory list and editor render in ${mode.name}',
        (tester) async {
      await mount(tester, const EquipmentScreen(), mode: mode);
      expect(find.text('Add equipment'), findsOneWidget);
      expect(find.byTooltip('Edit Padel racket'), findsOneWidget);
      expect(find.text('12 in stock'), findsWidgets);
      expect(find.text('Sample brand'), findsNothing);
      await capture(tester, 'inventory-${mode.name}');
      await tester.tap(find.byTooltip('Edit Padel racket'));
      await tester.pumpAndSettle();
      expect(find.text('Edit equipment'), findsOneWidget);
      await capture(tester, 'editor-${mode.name}');
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rentals'));
      await tester.pumpAndSettle();
      await capture(tester, 'rentals-${mode.name}');
      expect(find.textContaining('Confirmed · 2 units'), findsOneWidget);
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Returned · 2 units'), findsOneWidget);
      expect(find.textContaining('Confirmed · 2 units'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('admin can edit price stock and active state and refresh list',
      (tester) async {
    await mount(tester, const EquipmentScreen());
    await tester.tap(find.byTooltip('Edit Padel racket'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('equipment-name')), 'Updated racket');
    await show(tester, find.byKey(const ValueKey('equipment-pricePerSlot')));
    await tester.enterText(
        find.byKey(const ValueKey('equipment-pricePerSlot')), '650');
    await show(tester, find.byKey(const ValueKey('equipment-quantity')));
    await tester.enterText(
        find.byKey(const ValueKey('equipment-quantity')), '15');
    await show(tester, find.byType(SwitchListTile));
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('Save equipment'));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere((r) => r.method == 'PUT');
    expect(request.path, '/equipment/2');
    expect(request.data, containsPair('name', 'Updated racket'));
    expect(request.data, containsPair('pricePerSlot', 650));
    expect(request.data, containsPair('quantity', 15));
    expect(request.data, containsPair('isActive', false));
    expect(request.data, containsPair('venueId', 1));
    expect(find.text('Updated racket'), findsOneWidget);
  });
  testWidgets('new equipment selects compatible sport and venue and creates',
      (tester) async {
    await mount(tester, const EquipmentScreen());
    await tester.tap(find.text('Add equipment'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('equipment-name')), 'Practice balls');
    await tester
        .tap(find.widgetWithText(DropdownButtonFormField<int>, 'Sport'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cricket').last);
    await tester.pumpAndSettle();
    await show(tester, find.text('Shared inventory'));
    await tester.tap(find.text('Shared inventory'));
    await tester.pumpAndSettle();
    expect(find.text('Court A'), findsNothing);
    await tester.tap(find.text('Cricket ground').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save equipment'));
    await tester.pumpAndSettle();
    final request = api.requests.singleWhere((r) => r.method == 'POST');
    expect(request.path, '/equipment');
    expect(request.data['sportId'], 2);
    expect(request.data['venueId'], 2);
  });
  testWidgets('failed edit keeps values and presents server restriction',
      (tester) async {
    api.rejectSave = true;
    await mount(tester, EquipmentEditorScreen(item: api.item));
    await tester.enterText(
        find.byKey(const ValueKey('equipment-name')), 'Retained edit');
    await tester.tap(find.text('Save equipment'));
    await tester.pumpAndSettle();
    expect(find.text('Retained edit'), findsOneWidget);
    expect(
        find.textContaining('Finish or cancel active rentals'), findsOneWidget);
    expect(find.text('Edit equipment'), findsOneWidget);
  });
  testWidgets('invalid stock cannot be saved even after scrolling it offscreen',
      (tester) async {
    await mount(tester, EquipmentEditorScreen(item: api.item));
    await show(tester, find.byKey(const ValueKey('equipment-quantity')));
    await tester.enterText(
        find.byKey(const ValueKey('equipment-quantity')), '-1');
    await show(tester, find.byKey(const ValueKey('equipment-imageUrl')));
    await tester.tap(find.text('Save equipment'));
    await tester.pumpAndSettle();
    expect(api.requests.where((r) => r.method == 'PUT'), isEmpty);
    expect(find.textContaining('whole stock quantity'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
  testWidgets('admin return validates damage and sends inspection',
      (tester) async {
    await mount(tester, AdminRentalScreen(rental: api.rental('CONFIRMED')));
    await show(tester, find.byKey(const ValueKey('return-damaged')));
    await tester.enterText(find.byKey(const ValueKey('return-damaged')), '1');
    await show(tester, find.text('Record return'));
    await tester.tap(find.text('Record return'));
    await tester.pumpAndSettle();
    expect(find.text('Describe the damage'), findsOneWidget);
    await tester.enterText(
        find.byKey(const ValueKey('return-notes')), 'Grip split');
    await tester.tap(find.text('Record return'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm return'));
    await tester.pumpAndSettle();
    final post = api.requests.singleWhere((r) => r.method == 'POST');
    expect(post.path, '/equipment/rentals/8/return');
    expect(post.data, {'damagedQuantity': 1, 'damageNotes': 'Grip split'});
  });
  testWidgets('future confirmed rentals cannot be returned early',
      (tester) async {
    await mount(
        tester, AdminRentalScreen(rental: api.rental('CONFIRMED', days: 1)));
    expect(find.byKey(const ValueKey('return-damaged')), findsNothing);
    expect(find.text('Record return'), findsNothing);
    await show(tester, find.text('Cancel rental'));
    await tester.tap(find.text('Cancel rental'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Confirm cancellation'));
    await tester.pumpAndSettle();
    expect(api.requests.singleWhere((r) => r.method == 'POST').path,
        '/equipment/rentals/8/cancel');
  });
  testWidgets('admin search and filters change real list rows', (tester) async {
    await mount(tester, const EquipmentScreen());
    await tester.enterText(find.byType(TextField), 'Cricket');
    await tester.pumpAndSettle();
    expect(find.text('Padel racket'), findsNothing);
    expect(find.text('Cricket bat'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear search'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Inactive'));
    await tester.pumpAndSettle();
    expect(find.text('Padel racket'), findsNothing);
    expect(find.text('Cricket bat'), findsOneWidget);
  });
  testWidgets('admin list editor and returns support narrow large text',
      (tester) async {
    await mount(tester, const EquipmentScreen(), width: 320, scale: 1.5);
    await show(tester, find.byTooltip('Edit Padel racket'));
    await tester.tap(find.byTooltip('Edit Padel racket'));
    await tester.pumpAndSettle();
    await show(tester, find.byKey(const ValueKey('equipment-imageUrl')));
    expect(tester.takeException(), isNull);
    await mount(tester, AdminRentalScreen(rental: api.rental('CONFIRMED')),
        width: 320, scale: 1.5);
    await show(tester, find.text('Record return'));
    expect(tester.takeException(), isNull);
  });
}
