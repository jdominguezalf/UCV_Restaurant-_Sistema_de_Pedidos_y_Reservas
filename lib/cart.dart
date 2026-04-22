import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class Cart with ChangeNotifier {
  final Map<String, Map<String, dynamic>> _cartItems = {};

  Cart() {
    _loadFromStorage();
  }

  List<Map<String, dynamic>> get items => _cartItems.values.toList();

  int get itemCount => _cartItems.length;

  int get totalQuantity {
    int total = 0;
    _cartItems.forEach((_, item) {
      total += (item['quantity'] as int? ?? 0);
    });
    return total;
  }

  double get totalAmount {
    double total = 0.0;
    _cartItems.forEach((_, item) {
      final price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final qty = (item['quantity'] as int?) ?? 0;
      total += price * qty;
    });
    return total;
  }

  void addToCart(Map<String, dynamic> product) {
    final productId = product['name'] as String;
    if (_cartItems.containsKey(productId)) {
      final existing = _cartItems[productId]!;
      existing['quantity'] = (existing['quantity'] as int) + 1;
    } else {
      _cartItems[productId] = {
        'name': product['name'],
        'price': (product['price'] as num).toDouble(),
        'image': product['image'],
        'quantity': 1,
      };
    }
    _saveToStorage();
    notifyListeners();
  }

  void removeFromCart(Map<String, dynamic> product) {
    final productId = product['name'] as String;
    if (!_cartItems.containsKey(productId)) return;

    final existing = _cartItems[productId]!;
    final currentQty = (existing['quantity'] as int);
    if (currentQty > 1) {
      existing['quantity'] = currentQty - 1;
    } else {
      _cartItems.remove(productId);
    }
    _saveToStorage();
    notifyListeners();
  }

  void removeCompleteItem(String productId) {
    _cartItems.remove(productId);
    _saveToStorage();
    notifyListeners();
  }

  void clear() {
    _cartItems.clear();
    _saveToStorage();
    notifyListeners();
  }

  Future<void> _saveToStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_cartItems);
    await prefs.setString('cart_data', encoded);
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonData = prefs.getString('cart_data');
    if (jsonData != null) {
      final decoded = jsonDecode(jsonData) as Map<String, dynamic>;
      _cartItems.clear();
      decoded.forEach((key, value) {
        _cartItems[key] = Map<String, dynamic>.from(value);
      });
      notifyListeners();
    }
  }
}

// 👇 Esto va FUERA de la clase Cart
final cartProvider = ChangeNotifierProvider<Cart>((ref) => Cart());

