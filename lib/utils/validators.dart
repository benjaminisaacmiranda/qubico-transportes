class Validators {
  static String? validateRut(String? value) {
    if (value == null || value.trim().isEmpty) return 'El RUT es obligatorio';

    final rut = value.trim().toUpperCase();
    if (!rut.contains('-')) return 'El RUT debe incluir guion (ej: 12345678-9)';

    final partes = rut.split('-');
    if (partes.length != 2) return 'Formato inválido';

    final cuerpo = partes[0];
    final dvIngresado = partes[1];

    if (cuerpo.length < 7 || cuerpo.length > 8) return 'RUT inválido';
    if (!RegExp(r'^\d+$').hasMatch(cuerpo)) return 'RUT inválido';

    int suma = 0;
    int multiplicador = 2;
    for (int i = cuerpo.length - 1; i >= 0; i--) {
      suma += int.parse(cuerpo[i]) * multiplicador;
      multiplicador = multiplicador == 7 ? 2 : multiplicador + 1;
    }
    final resto = 11 - (suma % 11);
    final dvCorrecto = resto == 11 ? '0' : resto == 10 ? 'K' : resto.toString();

    if (dvIngresado != dvCorrecto) return 'RUT no válido (dígito verificador incorrecto)';
    return null;
  }

  static String? validatePhone(String? value) {
    if (value == null || value.isEmpty) {
      return 'El teléfono es obligatorio';
    }
    // RF1: Mobile phone (9 digits)
    final phoneRegex = RegExp(r'^[0-9]{9}$');
    if (!phoneRegex.hasMatch(value)) {
      return 'El teléfono debe tener exactamente 9 dígitos';
    }
    return null;
  }

  static String? validateEmail(String? value) {
    if (value == null || value.isEmpty) {
      return 'El correo es obligatorio';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value)) {
      return 'Ingrese un correo electrónico válido';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.isEmpty) {
      return '$fieldName es obligatorio';
    }
    return null;
  }
}
