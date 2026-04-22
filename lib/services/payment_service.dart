import 'dart:async';

class PaymentService {
  /// Simula el procesamiento de un pago
  /// Retorna true si se procesó correctamente, false si falló.
  Future<bool> processPayment({
    required String method,
    required double amount,
  }) async {
    // Simulamos un tiempo de espera (ejemplo: 2 segundos)
    await Future.delayed(const Duration(seconds: 2));

    // Por ahora todos los pagos se consideran exitosos
    // En el futuro aquí integras Stripe, Yape, PayPal, etc.
    return true;

    // Si quisieras simular fallos aleatorios:
    // return amount < 500; // Ejemplo: solo funciona si es menor a 500
  }
}