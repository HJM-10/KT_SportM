import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import 'admin_equipment_screen.dart';
import 'rental_shop_screen.dart';

class EquipmentScreen extends StatelessWidget {
  final int? venueId;
  const EquipmentScreen({super.key, this.venueId});
  @override
  Widget build(BuildContext context) =>
      context.watch<AuthProvider>().user?['role'] == 'ADMIN'
          ? AdminEquipmentScreen(venueId: venueId)
          : RentalShopScreen(venueId: venueId);
}
