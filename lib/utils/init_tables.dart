import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> initMesas() async {
  final db = FirebaseFirestore.instance;

  for (int i = 1; i <= 10; i++) {
    await db.collection("mesas").doc("mesa$i").set({
      "numero": i,
      "estado": "libre", // otros: pendiente, en_preparacion, servido
    });
  }
}