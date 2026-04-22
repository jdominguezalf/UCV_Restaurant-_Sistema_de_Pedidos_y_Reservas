import 'package:flutter/foundation.dart';

class SelectedTable extends ChangeNotifier {
  int? _mesaSeleccionada;

  int? get mesaSeleccionada => _mesaSeleccionada;

  void selectMesa(int numero) {
    _mesaSeleccionada = numero;
    notifyListeners();
  }

  void clearTable() {
    _mesaSeleccionada = null; // Limpia la mesa seleccionada
    notifyListeners();
  }
}