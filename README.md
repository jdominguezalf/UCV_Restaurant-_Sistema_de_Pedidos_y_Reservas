# UCV Restaurant – Sistema de Pedidos y Reservas

## Descripción
UCV Restaurant es una aplicación desarrollada para gestionar pedidos y reservas de manera digital, permitiendo la interacción entre usuarios y el sistema mediante una interfaz intuitiva conectada a servicios en la nube.

## Objetivo del proyecto
Digitalizar el flujo de pedidos y reservas de un entorno similar al de un restaurante, mejorando la organización de productos, órdenes y experiencia de usuario mediante una aplicación híbrida.

## Tecnologías y software utilizados
- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Console
- Visual Studio Code
- Android Studio
- Git y GitHub

## Base de datos utilizada
Se utilizó **Cloud Firestore** como base de datos NoSQL para gestionar:
- usuarios
- productos
- pedidos
- reservas
- estados de atención o procesamiento

## Arquitectura del sistema
El proyecto se basa en una arquitectura cliente-servidor:
- **Cliente:** aplicación híbrida desarrollada en Flutter
- **Backend:** Firebase
- **Base de datos:** Cloud Firestore
- **Autenticación:** Firebase Authentication

## Funcionamiento del sistema
El funcionamiento principal del sistema sigue este flujo:

1. El usuario accede al sistema mediante autenticación.
2. La aplicación consulta en Firestore los productos o servicios disponibles.
3. El usuario puede realizar pedidos o registrar reservas.
4. Los datos ingresados son almacenados en la base de datos cloud.
5. El sistema organiza la información para su consulta posterior.
6. Los cambios registrados pueden visualizarse de forma dinámica desde la aplicación.

## Funcionamiento en tiempo real
Gracias al uso de **Cloud Firestore**, el sistema actualiza automáticamente la información visible en la app cuando se produce algún cambio en la base de datos.

Esto permite:
- ver nuevos pedidos sin recargar la app
- actualizar estados de órdenes
- sincronizar reservas o productos de manera inmediata

## Funcionalidades principales
- autenticación de usuarios
- consulta de productos
- gestión de pedidos
- registro de reservas
- sincronización de información en la nube
- interacción dinámica con la base de datos

## Rol desarrollado en el proyecto
- desarrollo de la interfaz del sistema
- conexión con Firebase
- diseño de lógica para pedidos y reservas
- organización de información en base de datos
- estructuración del flujo de interacción usuario-sistema

## Capturas del sistema
Agregar imágenes de:
- login
- menú principal
- pedidos
- reservas
- confirmación de acciones

## Aprendizajes obtenidos
- diseño de soluciones orientadas a procesos organizacionales
- uso de servicios cloud para sincronización de datos
- modelado de flujos de usuario
- implementación de lógica de pedidos y reservas

## Mejoras futuras
- panel administrativo
- notificaciones en tiempo real
- gestión de estados más detallada
- reportes de pedidos y reservas
