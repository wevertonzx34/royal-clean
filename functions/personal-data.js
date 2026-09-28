import {normalizeDocument, normalizePhone, validDocument, validName} from './validation.js';

// Accept only editable fields. Roles, identity checks and benefits never come from the client.
export function personalData(input, previous, user) {
  if (!validName(input.name) || typeof input.offers !== 'boolean') throw Error('Confira nome e preferência de ofertas.');
  const text = (key, max) => {
    const value = input[key] ?? previous[key] ?? '';
    if (typeof value !== 'string' || value.length > max || /[\p{Cc}\p{Cf}<>]/u.test(key === 'description' ? value.replace(/[\r\n]/g, '') : value)) throw Error(`Confira o campo ${key}.`);
    return value.trim();
  };
  const kind = input.personType ?? previous.personType ?? (input.documentKind === 'cnpj' || previous.documentKind === 'cnpj' ? 'company' : 'individual');
  if (!['individual', 'company'].includes(kind)) throw Error('Escolha pessoa física ou jurídica.');
  for (const key of ['cpf', 'cnpj']) {
    if (key in input && typeof input[key] !== 'string') throw Error('Confira o CPF ou CNPJ informado.');
  }
  let cpf = normalizeDocument(input.cpf ?? previous.cpf ?? (previous.documentKind === 'cpf' ? previous.document : ''));
  let cnpj = normalizeDocument(input.cnpj ?? previous.cnpj ?? (previous.documentKind === 'cnpj' ? previous.document : ''));
  if ('document' in input && !('cpf' in input) && !('cnpj' in input)) {
    if (typeof input.document !== 'string' || !validDocument(input.documentKind ?? '', input.document)) throw Error('Confira o CPF ou CNPJ informado.');
    cpf = input.documentKind === 'cpf' ? normalizeDocument(input.document) : '';
    cnpj = input.documentKind === 'cnpj' ? normalizeDocument(input.document) : '';
  }
  if (cpf && !validDocument('cpf', cpf)) throw Error('Confira o CPF informado.');
  if (cnpj && !validDocument('cnpj', cnpj)) throw Error('Confira o CNPJ informado.');
  const companyLegalName = text('companyLegalName', 160);
  if (kind === 'company' && (!cnpj || !validName(companyLegalName))) throw Error('Informe CNPJ válido e razão social para pessoa jurídica.');
  const rawPhone = text('phone', 30);
  const phone = rawPhone ? normalizePhone(rawPhone) : '';
  if (rawPhone && !phone) throw Error('Informe um telefone brasileiro com DDD.');
  const media = key => {
    const value = input[key] ?? previous[key] ?? '';
    const file = key === 'photoPath' ? 'photo' : 'logo';
    if (value !== '' && value !== `profile_media/${user.uid}/${file}.png`) throw Error('Imagem de perfil inválida.');
    return value;
  };
  const documentKind = kind === 'company' ? 'cnpj' : cpf ? 'cpf' : '';
  return {
    name: input.name.trim(), offers: input.offers, personType: kind,
    cpf, cnpj, documentKind, document: documentKind === 'cnpj' ? cnpj : cpf,
    companyLegalName, tradeName: text('tradeName', 160), description: text('description', 1000),
    phone, phoneVerified: Boolean(phone && phone === normalizePhone(user.phoneNumber)),
    photoPath: media('photoPath'), logoPath: media('logoPath'),
    postalCode: text('postalCode', 10), address: text('address', 180),
    addressNumber: text('addressNumber', 20), complement: text('complement', 100),
    district: text('district', 100), city: text('city', 100), state: text('state', 2).toUpperCase(),
    documentStatus: cpf || cnpj ? 'format_valid' : 'not_provided',
  };
}
