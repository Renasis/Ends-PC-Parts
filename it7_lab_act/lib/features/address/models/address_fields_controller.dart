import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../data/ph_locations.dart';
import 'address_label.dart';
import 'shipping_address.dart';

/// Holds the text controllers, label and map pin for one address form, so the
/// profile sheet and the checkout screen can share the same fields.
///
/// The ZIP code is suggested from the city (see [PhLocations]) while the
/// customer has not typed their own. Typing a ZIP code always wins.
class AddressFieldsController extends ChangeNotifier {
  final street = TextEditingController();
  final barangay = TextEditingController();
  final city = TextEditingController(text: ShippingAddress.defaultCity);
  final province = TextEditingController(text: ShippingAddress.defaultProvince);
  final zip = TextEditingController();
  final landmark = TextEditingController();

  /// The last ZIP code this controller filled in by itself.
  String _autoZip = '';

  AddressFieldsController() {
    city.addListener(_suggestZip);
    province.addListener(_suggestZip);
    _suggestZip();
  }

  AddressLabel _label = AddressLabel.home;
  AddressLabel get label => _label;
  set label(AddressLabel value) {
    _label = value;
    notifyListeners();
  }

  LatLng? _pin;
  LatLng? get pin => _pin;
  set pin(LatLng? value) {
    _pin = value;
    notifyListeners();
  }

  /// True while the ZIP code in the box is our suggestion, not the customer's.
  bool get zipIsSuggested => _autoZip.isNotEmpty && zip.text == _autoZip;

  /// Rebuilds when any field, the label or the pin changes.
  Listenable get changes => Listenable.merge(
        [this, street, barangay, city, province, zip, landmark],
      );

  void _suggestZip() {
    final suggestion = PhLocations.zipFor(city.text, province.text);

    if (suggestion == null) {
      // The old suggestion belonged to a different city: take it back.
      if (zip.text.isNotEmpty && zip.text == _autoZip) {
        zip.clear();
        _autoZip = '';
        notifyListeners();
      }
      return;
    }

    final canReplace = zip.text.isEmpty || zip.text == _autoZip;
    if (!canReplace || zip.text == suggestion) return;

    zip.text = suggestion;
    _autoZip = suggestion;
    notifyListeners();
  }

  /// Fills the form from a saved address. An empty city or province keeps the
  /// default so the form is never blank in those boxes. A saved address with
  /// no ZIP code (older accounts) gets a suggestion when the city is known.
  void load(ShippingAddress address) {
    _autoZip = '';
    zip.text = address.zipCode;
    street.text = address.street;
    barangay.text = address.barangay;
    landmark.text = address.landmark;
    city.text =
        address.city.isNotEmpty ? address.city : ShippingAddress.defaultCity;
    province.text = address.province.isNotEmpty
        ? address.province
        : ShippingAddress.defaultProvince;
    _label = address.label;
    _pin = address.hasPin ? LatLng(address.latitude!, address.longitude!) : null;
    notifyListeners();
  }

  ShippingAddress toAddress() => ShippingAddress(
        label: _label,
        street: street.text.trim(),
        barangay: barangay.text.trim(),
        city: city.text.trim(),
        province: province.text.trim(),
        zipCode: zip.text.trim(),
        landmark: landmark.text.trim(),
        latitude: _pin?.latitude,
        longitude: _pin?.longitude,
      );

  @override
  void dispose() {
    street.dispose();
    barangay.dispose();
    city.dispose();
    province.dispose();
    zip.dispose();
    landmark.dispose();
    super.dispose();
  }
}
