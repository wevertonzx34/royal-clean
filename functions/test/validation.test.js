import {test} from 'node:test';
import assert from 'node:assert/strict';
import {validName, validDocument, inviteProblem} from '../validation.js';

test('names support accents and international formats, reject empty/control markup', () => {
  for (const name of ['João', '李明', 'Ana-Maria D’Ávila', 'Al']) assert.equal(validName(name), true);
  for (const name of ['', ' ', 'a', '<script>', 'Ana\nMaria', '12345']) assert.equal(validName(name), false);
});
test('documents validate CPF, numeric and alphanumeric CNPJ with check digits', () => {
  assert.equal(validDocument('', ''), true);
  assert.equal(validDocument('cpf', '529.982.247-25'), true);
  assert.equal(validDocument('cpf', '52998224724'), false);
  assert.equal(validDocument('cpf', '11111111111'), false);
  assert.equal(validDocument('cnpj', '11.222.333/0001-81'), true);
  assert.equal(validDocument('cnpj', '12.ABC.345/01DE-35'), true);
  assert.equal(validDocument('cnpj', '12.ABC.345/01DE-34'), false);
  assert.equal(validDocument('cpf', ''), false);
  assert.equal(validDocument('unexpected', ''), false);
  assert.equal(validDocument('cnpj', '00000000000000'), false);
});
test('invites reject missing, used, expired and disabled records', () => {
  const valid = {registrationEnabled:true, isUsed:false, status:'processing'};
  assert.equal(inviteProblem(valid, 1000), null);
  for (const data of [null, {...valid,isUsed:true}, {...valid,usedByUid:'uid'},
    {...valid,registrationEnabled:false}, {...valid,status:'cancelled'},
    {...valid,expiresAt:{toMillis:()=>999}}, {...valid,expiresAt:'invalid'}]) {
    assert.equal(typeof inviteProblem(data, 1000), 'string');
  }
  assert.equal(inviteProblem({...valid,expiresAt:{toMillis:()=>1001}},1000), null);
});
