export const LEGAL_VERSION = '2026-09-22';
export const ROLES = ['consumer', 'collaborator', 'promoter', 'master'];

export function validName(value) {
  return typeof value === 'string' && value.trim().length >= 2 &&
    value.trim().length <= 160 && !/[\p{Cc}\p{Cf}<>]/u.test(value) && /\p{L}/u.test(value);
}

export function normalizeDocument(value) {
  return typeof value === 'string' ? value.replace(/[.\/\-\s]/g, '').toUpperCase() : '';
}

// Format/check digits only; this does not establish ownership or fiscal status.
export function validDocument(kind, raw) {
  const value = normalizeDocument(raw);
  if (!value) return kind === '';
  if (/^(.)\1+$/.test(value)) return false;
  if (kind === 'cpf' && /^\d{11}$/.test(value)) {
    for (let length = 9; length <= 10; length++) {
      const sum = [...value.slice(0, length)].reduce((s, c, i) => s + Number(c) * (length + 1 - i), 0);
      const digit = (sum * 10 % 11) % 10;
      if (digit !== Number(value[length])) return false;
    }
    return true;
  }
  if (kind === 'cnpj' && /^[A-Z0-9]{12}\d{2}$/.test(value)) {
    for (let length = 12; length <= 13; length++) {
      const sum = [...value.slice(0, length)].reduce((s, c, i) =>
        s + (c.charCodeAt(0) - 48) * ((length - 1 - i) % 8 + 2), 0);
      const mod = sum % 11;
      if ((mod < 2 ? 0 : 11 - mod) !== Number(value[length])) return false;
    }
    return true;
  }
  return false;
}

export function inviteProblem(invite, now) {
  if (!invite) return 'Código inválido. Confira ou continue sem código.';
  if (invite.isUsed || invite.usedByUid) return 'Código já utilizado. Continue sem código para criar uma conta comum.';
  if (invite.expiresAt && (!invite.expiresAt.toMillis || invite.expiresAt.toMillis() <= now)) {
    return 'Código expirado. Continue sem código para criar uma conta comum.';
  }
  if (invite.registrationEnabled !== true || invite.status !== 'processing') {
    return 'Código indisponível. Continue sem código para criar uma conta comum.';
  }
  return null;
}

// Brazilian national numbers or +55; normalize before comparing invitation data.
export function normalizePhone(value) {
  if (typeof value !== 'string' || !/^[+0-9()\s-]+$/.test(value)) return null;
  const digits = value.replace(/\D/g, '');
  const national = (digits.length === 12 || digits.length === 13) && digits.startsWith('55') ? digits.slice(2) : digits;
  return /^[1-9][0-9]{9,10}$/.test(national) ? `55${national}` : null;
}
