import {test} from 'node:test';
import assert from 'node:assert/strict';
import {personalData} from '../personal-data.js';
const user = {uid:'owner',phoneNumber:'+5562999998888'};
const base = {name:'Consumidor Teste', offers:false};
test('consumer starts as individual and privilege fields are ignored', () => {
  const result = personalData({...base, role:'admin', active:true, phoneVerified:true}, {}, user);
  assert.equal(result.personType,'individual'); assert.equal(result.phoneVerified,false);
  assert.equal(result.role,undefined); assert.equal(result.active,undefined);
});
test('company requires valid CNPJ and legal name; CPF is optional', () => {
  const company = {...base,personType:'company',cnpj:'62.581.826/0001-49',companyLegalName:'Royal Clean LTDA'};
  assert.equal(personalData(company,{},user).document,'62581826000149');
  assert.throws(()=>personalData({...company,companyLegalName:''},{},user));
  assert.throws(()=>personalData({...company,cnpj:'11111111111111'},{},user));
  assert.throws(()=>personalData({...base,cpf:123},{},user));
});
test('phone verification comes from Auth, never from request or stored flags', () => {
  assert.equal(personalData({...base,phone:'(62) 99999-8888'},{},user).phoneVerified,true);
  assert.equal(personalData({...base,phone:'(62) 99999-1111',phoneVerified:true},{phoneVerified:true},user).phoneVerified,false);
});
test('media ownership and description validation', () => {
  assert.throws(()=>personalData({...base,photoPath:'profile_media/other/photo.png'},{},user));
  assert.throws(()=>personalData({...base,description:'<script>'},{},user));
  const result=personalData({...base,description:'Linha um\nLinha dois',photoPath:'profile_media/owner/photo.png'},{},user);
  assert.equal(result.description,'Linha um\nLinha dois');
});
test('legacy CPF, clearing documents, and optional fields survive updates', () => {
  const previous={documentKind:'cpf',document:'52998224725',description:'Minha descrição'};
  assert.equal(personalData(base,previous,user).cpf,'52998224725');
  const result=personalData({...base,documentKind:'',document:''},previous,user);
  assert.equal(result.cpf,''); assert.equal(result.description,previous.description);
});
