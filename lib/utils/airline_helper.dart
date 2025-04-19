import 'package:flutter/material.dart';

/// Clase utilitaria para manejar propiedades y operaciones relacionadas con aerolíneas
class AirlineHelper {
  /// Retorna el color correspondiente a cada aerolínea según su código
  static Color getAirlineColor(String airline) {
    switch (airline) {
      case 'SK':
        return const Color.fromARGB(255, 33, 150, 243); // Azul/Blue
      case 'DY':
      case 'D8': // Mismo color que DY (Norwegian)
        return const Color.fromARGB(255, 255, 68, 68); // Rojo/Red
      case 'DX':
        return const Color.fromARGB(255, 76, 175, 80); // Verde/Green
      case 'AY':
      case 'LX': // Swiss - Fondo blanco
      case 'HU': // Hainan Airlines - Fondo blanco
      case 'FI': // Icelandair - Fondo blanco
      case 'ET': // Ethiopian Airlines - Fondo blanco
      case 'VY': // Vueling - Fondo blanco
      case 'BA': // British Airways - Fondo blanco
      case 'W6': // Wizz Air - Fondo blanco
      case 'AF': // Air France - Fondo blanco
      case 'LO': // LOT Polish Airlines - Fondo blanco
      case 'W': // Wideroe - Fondo blanco
      case 'KL': // KLM Royal Dutch Airlines - Fondo blanco
        return Colors.white; // Blanco/White
      case 'TK': // Turkish Airlines
        return const Color.fromARGB(255, 220, 0, 0); // Rojo/Red
      case 'LH': // Lufthansa
        return const Color.fromARGB(255, 255, 204, 0); // Amarillo/Yellow
      case 'IB': // Iberia
        return Colors.white; // Blanco/White
      case 'BT': // Air Baltic
        return const Color.fromARGB(255, 255, 204, 0); // Amarillo/Yellow
      case 'FR': // Ryanair
      case 'RK':
        return const Color.fromARGB(255, 0, 51, 102); // Azul oscuro/Dark blue
      case 'TG': // Thai Airways
        return const Color.fromARGB(255, 123, 31, 162); // Violeta/Purple
      default:
        return Colors.grey; // Gris por defecto/Default grey
    }
  }

  /// Determina si se debe usar texto oscuro o claro según el color de fondo
  static Color getTextColorForAirline(String airline) {
    switch (airline) {
      case 'AY':
        return const Color.fromARGB(255, 0, 114, 206); // Azul/Blue para Finnair
      case 'LH': // Lufthansa
        return const Color.fromARGB(255, 0, 47, 135); // Azul/Blue
      case 'IB': // Iberia
        return const Color.fromARGB(255, 210, 0, 0); // Rojo/Red
      case 'BT': // Air Baltic
        return const Color.fromARGB(255, 0, 47, 135); // Azul/Blue
      case 'LX': // Swiss
        return const Color.fromARGB(255, 220, 0, 0); // Rojo/Red
      case 'HU': // Hainan Airlines
        return const Color.fromARGB(255, 220, 0, 0); // Rojo/Red
      case 'FI': // Icelandair
        return const Color.fromARGB(255, 0, 94, 184); // Azul/Blue
      case 'TG': // Thai Airways
        return const Color.fromARGB(255, 255, 215, 0); // Dorado/Gold
      case 'ET': // Ethiopian Airlines
        return const Color.fromARGB(255, 220, 0, 0); // Rojo/Red
      case 'VY': // Vueling
        return const Color.fromARGB(255, 255, 204, 0); // Amarillo/Yellow
      case 'BA': // British Airways
        return const Color.fromARGB(255, 0, 85, 155); // Azul/Blue
      case 'W6': // Wizz Air
        return const Color.fromARGB(255, 206, 0, 124); // Rosa/Pink
      case 'AF': // Air France
        return const Color.fromARGB(255, 0, 0, 205); // Azul/Blue
      case 'LO': // LOT Polish Airlines
        return const Color.fromARGB(255, 0, 92, 169); // Azul/Blue
      case 'W': // Wideroe
        return const Color.fromARGB(255, 0, 132, 61); // Verde/Green
      case 'KL': // KLM Royal Dutch Airlines
        return const Color.fromARGB(255, 0, 106, 170); // Azul/Blue (KLM blue)
      default:
        return Colors.white; // Blanco/White para la mayoría de aerolíneas
    }
  }
}
