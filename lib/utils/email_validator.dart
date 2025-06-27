/// Utilidad para validar emails y prevenir el uso de servicios de email temporales
class EmailValidator {
  // Lista de dominios de servicios de email temporales conocidos
  static const List<String> _temporaryEmailDomains = [
    // Yopmail y variantes
    'yopmail.com',
    'yopmail.fr',
    'yopmail.net',
    'cool.fr.nf',
    'jetable.fr.nf',
    'nospam.ze.tc',
    'nomail.xl.cx',
    'mega.zik.dj',
    'speed.1s.fr',
    'courriel.fr.nf',
    'moncourrier.fr.nf',
    'monemail.fr.nf',
    'monmail.fr.nf',
    'hide.biz.st',
    'mymail.infos.st',
    
    // 10 Minute Mail
    '10minutemail.com',
    '10minutemail.net',
    '10minutemail.de',
    '10minutemail.co.uk',
    'tempail.com',
    'tempmail.eu',
    
    // Guerrilla Mail
    'guerrillamail.info',
    'guerrillamail.biz',
    'guerrillamail.com',
    'guerrillamail.de',
    'guerrillamail.net',
    'guerrillamail.org',
    'guerrilla-mail.com',
    'grr.la',
    'sharklasers.com',
    'spam4.me',
    'bccto.me',
    'chacuo.net',
    'guerrillamailblock.com',
    
    // Mailinator
    'mailinator.com',
    'mailinator.net',
    'mailinator.org',
    'mailinator2.com',
    'sogetthis.com',
    'bobmail.info',
    'spamherelots.com',
    'thisisnotmyrealemail.com',
    'binkmail.com',
    'safetymail.info',
    'objectmail.com',
    'proxymail.eu',
    'rcpt.at',
    'dingbone.com',
    'inboxalias.com',
    'beefmilk.com',
    'tradermail.info',
    
    // TempMail
    'tempmail.org',
    'temp-mail.org',
    'temp-mail.io',
    'tempmail.net',
    'tempmail.io',
    'temp-mail.ru',
    'tempmail24.com',
    'mailtemp.info',
    'tmpeml.info',
    'emailtemp.info',
    'tempinbox.com',
    'temp-inbox.com',
    'mailnesia.com',
    'tempail.net',
    
    // Mohmal
    'mohmal.com',
    'mohmal.in',
    'mohmal.tech',
    
    // ThrowAwayMail
    'throwawaymail.com',
    'throwawaymails.com',
    'throwaway.email',
    'thrash.email',
    'moakt.com',
    'moakt.cc',
    'dispostable.com',
    
    // Otros servicios populares
    'maildrop.cc',
    'tempsky.com',
    'fakemailgenerator.com',
    'fake-email.org',
    'emailfake.com',
    'email-generator.org',
    'getnada.com',
    'correotemporal.org',
    'correo-temporal.com',
    'emailondeck.com',
    'emailnator.com',
    'emaildrop.io',
    'discard.email',
    'burnermail.io',
    'sharklasers.com',
    'guerrillamail.info',
    'anonbox.net',
    'anonymousemail.me',
    'tempemails.net',
    'lroid.com',
    'tmlwiz.com',
    'luxusmail.org',
    'guerrillamail.de',
    'spamfree24.org',
    'spamfree24.de',
    'spamfree24.com',
    'spamfree24.net',
    '20minutemail.it',
    'minuteinbox.com',
    'inboxkitten.com',
    'mail.tm',
    '1secmail.com',
    '1secmail.org',
    '1secmail.net',
    'anonaddy.me',
    'simplelogin.io',
    'relay.firefox.com',
    'duck.com',
    'emailondeck.com',
    'emailnator.com',
    'gmailnator.com',
    'inboxes.com',
    'incognitomail.org',
    'mailcatch.com',
    'mailsac.com',
    'temp-mail.com',
    'tempmail.plus',
    'tempmaildrop.com',
    'temp-mails.com',
    'tempmailaddress.com',
    'opayq.com',
    'rootfest.net',
    'tempail.club',
    'email-fake.com',
    'fakemail.net',
    'fakeinbox.com',
    'mailbox.in.ua',
    'mailbox.co.za',
    'mailhazard.com',
    'mytrashmail.com',
    'trashmail.net',
    'trashmailgenerator.com',
    'trashymail.com',
    '33mail.com',
    'spamgourmet.com',
    'jetable.org',
    'jetable.net',
    '10mail.org',
    '20mail.it',
    '2prong.com',
    'airmail.cc',
    'bouncr.com',
    'deadaddress.com',
    'dumpmail.de',
    'emailias.com',
    'emkei.cz',
    'fake-box.com',
    'fakemailgenerator.net',
    'filzmail.com',
    'fudgerub.com',
    'getairmail.com',
    'gishpuppy.com',
    'guerrillamail.biz',
    'harakirimail.com',
    'hush.ai',
    'inboxclean.com',
    'inboxclean.org',
    'jessejames.top',
    'koszmail.pl',
    'kuku.lu',
    'lhsdv.com',
    'litedrop.com',
    'maildx.com',
    'mailin8r.com',
    'mailmetrash.com',
    'mailnull.com',
    'mailzilla.com',
    'mintemail.com',
    'mx0.wwwnew.eu',
    'nice-4u.com',
    'noclickemail.com',
    'oopi.org',
    'privacy.net',
    'punkass.com',
    'put2.net',
    'qzueos.com',
    'shopmail.ro',
    'spam.la',
    'spamex.com',
    'spamhole.com',
    'spamif.org',
    'spammotel.com',
    'spamstack.net',
    'spamthis.co.uk',
    'speed.1s.fr',
    'superrito.com',
    'suremail.info',
    'tempemail.biz',
    'tempemail.co.za',
    'tempemail.net',
    'tempinbox.org',
    'tempmail.de',
    'tempmail.it',
    'tempsky.com',
    'thanksnospam.info',
    'trash2009.com',
    'uggsrock.com',
    'vomoto.com',
    'webm4il.info',
    'xtom.info',
    'yep.it',
    'zoemail.com',
    'zoemail.net',
    'zoemail.org',
  ];

  /// Valida si un email tiene un formato válido y no es de un servicio temporal
  static EmailValidationResult validateEmail(String email) {
    // Primero verificar formato básico
    if (email.isEmpty) {
      return EmailValidationResult(
        isValid: false,
        error: 'Por favor, introduce un email',
      );
    }

    // Regex mejorado para validación de email
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(email)) {
      return EmailValidationResult(
        isValid: false,
        error: 'Por favor, introduce un email válido',
      );
    }

    // Extraer dominio del email
    final domain = email.split('@').last.toLowerCase();

    // Verificar si es un dominio temporal
    if (_temporaryEmailDomains.contains(domain)) {
      return EmailValidationResult(
        isValid: false,
        error: 'No se permiten emails temporales o desechables.\nPor favor, usa un email permanente.',
        isTemporary: true,
      );
    }

    // Email válido
    return EmailValidationResult(
      isValid: true,
    );
  }

  /// Verifica solo si un email es de un servicio temporal
  static bool isTemporaryEmail(String email) {
    if (email.isEmpty || !email.contains('@')) {
      return false;
    }

    final domain = email.split('@').last.toLowerCase();
    return _temporaryEmailDomains.contains(domain);
  }

  /// Verifica solo el formato del email sin verificar dominios temporales
  static bool isValidEmailFormat(String email) {
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email);
  }

  /// Lista de dominios temporales para uso externo si es necesario
  static List<String> get temporaryDomains => List.unmodifiable(_temporaryEmailDomains);
}

/// Resultado de la validación de email
class EmailValidationResult {
  final bool isValid;
  final String? error;
  final bool isTemporary;

  const EmailValidationResult({
    required this.isValid,
    this.error,
    this.isTemporary = false,
  });
}
