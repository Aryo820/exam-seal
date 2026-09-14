const assert = require('node:assert/strict');
const vm = require('node:vm');
const source = require('node:fs').readFileSync('lib/widgets/restricted_form_view.dart', 'utf8');
const script = source.split("'''")[1].replace('${jsonEncode(formPath)}', '"/forms/d/e/pilot"');
const callbacks = {}, messages = [];
let fileInput = null, mutation;
class Form {
  constructor(action) { this.action = action; this.target = ''; }
  querySelector() { return fileInput; }
  submit() { this.sent = true; }
}
const form = new Form('https://docs.google.com/forms/d/e/pilot/formResponse');
const document = {
  forms: [form], documentElement: {}, querySelector: () => fileInput,
  addEventListener: (name, fn) => callbacks[name] = fn,
};
const window = {};
const context = {
  window, document, URL, location: {href: 'https://docs.google.com/forms/d/e/pilot/viewform'},
  HTMLFormElement: Form, ExamSealForm: {postMessage: value => messages.push(value)},
  MutationObserver: class { constructor(fn) { mutation = fn; } observe() {} },
};
const result = vm.runInNewContext(script, context);
assert.equal(result.hasForm, true);
assert.equal(result.upload, false);
assert.equal(window.open('https://example.com'), null);
for (const a of [
  {href: 'https://example.com', target: ''},
  {href: 'https://docs.google.com/forms/d/e/other/viewform', target: ''},
  {href: form.action, target: '_blank'},
  {href: 'https://docs.google.com/forms/d/e/pilot/viewform?edit2=token', target: ''},
  {href: form.action, target: '', download: true},
]) {
  let stopped = false;
  a.hasAttribute = () => !!a.download;
  callbacks.click({target: {closest: () => a}, preventDefault: () => stopped = true, stopImmediatePropagation() {}});
  assert.equal(stopped, true);
}
form.submit();
assert.equal(form.sent, true);
const external = new Form('https://example.com/collect');
external.submit();
assert.equal(external.sent, undefined);
fileInput = {};
mutation();
assert.equal(messages.at(-1), 'unsupported');
form.sent = false;
form.submit();
assert.equal(form.sent, false);
console.log('Guard JavaScript: navigasi, jendela baru, download, submit sah, POST luar, upload: lulus.');
