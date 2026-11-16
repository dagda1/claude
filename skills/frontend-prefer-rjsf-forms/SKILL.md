---
name: frontend-prefer-rjsf-forms
description: Never build a form with its own field state, validation and error display — write a FormSchema and render it with Form from @harbour/form, which wraps rjsf, in Harbour frontend
triggers:
  - model
  - user
---

# Prefer an rjsf form over a bespoke form

A custom form is a `useState` per field, an `onChange` per input, a `validate()` that
returns an error map, a `showErrors` flag, helper text per field and a submit handler that
checks it all again. Every one of those gets written slightly differently each time:
required fields that accept spaces, a URL check that disagrees with the backend, errors
that never clear, no character counters, no layout. `Form` from `@harbour/form` wraps
`@rjsf/core` and does all of it from a JSON Schema.

## Rule

A form with more than one input, or with any validation, is a `FormSchema` rendered by
`Form` from `@harbour/form`. Do not:

- keep a `useState` per field, or one draft object updated by your own `onChange`s;
- write a `validate…()` / `…Errors` function, an error map, or a `showErrors` flag;
- render `TextField`, `Select`, `Switch` or a date picker as form fields with your own
  `error` / `helperText` wiring;
- reimplement required, max length, patterns or conditional fields that JSON Schema
  already expresses.

## How to express it

| Need                                                       | Use                                                                                 |
| ---------------------------------------------------------- | ----------------------------------------------------------------------------------- |
| Required field                                             | `required: [...]` on the object schema                                              |
| Length limit (and the counter)                             | `maxLength`                                                                         |
| Format check (URL, code)                                   | `pattern`, with `errorMessage: { pattern: translate(...) }` (ajv-errors)            |
| Fields that appear and become required when a toggle is on | `if` / `then` on the object schema                                                  |
| Field B required when field A is filled                    | `dependencies: { a: ['b'] }`                                                        |
| An English and a French field for the same text            | `languagePair` from `@harbour/form` (see below)                                     |
| A select with labels                                       | `oneOf: [{ const, title }]`, or `enum`; `ui:options.optionValueFormat: 'realValue'` |
| A toggle                                                   | `type: 'boolean'` with `'ui:field': 'switch'`                                       |
| Date, time, date and time                                  | `'ui:field': 'dateField'` / `'timeField'` / `'dateTimeField'`                       |
| Cross-field rule (end after start)                         | `customValidate`                                                                    |
| Defaults                                                   | `default` in the schema, or `defaultFormDataState`                                  |
| Fields per row                                             | `formLayout: '1column' \| '2column' \| '3column'`, field order with `ui:order`      |
| Live preview of what is typed                              | the `onChange` prop                                                                 |
| Cancel in the footer                                       | `onCancel` with `cancelPlacement="footer"`                                          |

Build the `FormSchema` in code when it is not a flow form:
`{ steps: [{ schema, mergedSchema: schema, uiSchema, title: '', path: '' }] }`, with every
title and placeholder from `translate()`. Parse `event.formData` with a Zod schema in
`onSubmit` / `onChange`. It comes from an untyped source.

`apps/frontend/src/pages/CreateBanner/bannerFormSchema.ts` and `BannerDetailsForm.tsx` are
a full reference. They use `if`/`then`, a pattern with its own message, `customValidate`,
`2column` layout, real-value selects, switches, date-time fields and an `onChange` preview.

## Bilingual fields

Text the user enters in both languages is always a pair, `<name>En` and `<name>Fr`, built
by `languagePair` from `@harbour/form`. Never write the two properties, their `required`
entries or their `dependencies` yourself. A pair is filled in both languages or neither:

- `rule: 'required'` — both are required (a title, or link text once its switch is on).
- `rule: 'bothOrNeither'` — optional, but filling one makes the other required (a description).

Spread the parts it returns into the schema, including inside an `if`/`then`:

```ts
const description = languagePair({
  name: 'description',
  title: translate('...descriptionLabel'),
  languageLabels: { en: translate('...english'), fr: translate('...french') },
  rule: 'bothOrNeither',
  field: { maxLength: DESCRIPTION_MAX_LENGTH },
  ui: { 'ui:widget': 'textarea' },
});

const schema: RJSFSchema = {
  type: 'object',
  required: [...title.required, 'type'],
  properties: { ...title.properties, ...description.properties },
  dependencies: description.dependencies,
};
const uiSchema: UiSchema = { ...title.uiSchema, ...description.uiSchema };
```

Map the pair to a `LocalizedText` with `toLocalizedText(en, fr)` from `@harbour/translator`.

## Missing a capability

If `Form` or its fields lack something, extend `@harbour/form`: add a field in
`packages/form/src/fields`, a widget, or a prop on `Form` such as `onChange`. Never fall
back to a custom form for one page. Work that walks or validates the schema itself is
covered by `rjsf-first`.

## Example

```tsx
// BAD — the component owns field state, validation and error display
const [title, setTitle] = useState('');
const [url, setUrl] = useState('');
const [showErrors, setShowErrors] = useState(false);
const errors = { title: !title.trim() && 'required', url: !url.startsWith('https://') && 'invalidUrl' };

<TextField value={title} onChange={(e) => setTitle(e.target.value)} error={showErrors && !!errors.title} />
<Button onClick={() => (Object.values(errors).some(Boolean) ? setShowErrors(true) : save({ title, url }))} />
```

```tsx
// GOOD
const schema: RJSFSchema = {
  type: 'object',
  required: ['title', 'url'],
  properties: {
    title: { type: 'string', title: translate('...title'), maxLength: 100 },
    url: {
      type: 'string',
      title: translate('...url'),
      pattern: '^https://.+',
      errorMessage: { pattern: translate('...invalidUrl') },
    },
  },
};

<Form
  formSchema={{ steps: [{ schema, mergedSchema: schema, uiSchema: {}, title: '', path: '' }] }}
  onSubmit={(event) => save(linkSchema.parse(event.formData))}
/>;
```

## When a bespoke input is acceptable

Inputs that are not a form: a single search box, a filter or sort select above a table, a
toggle that saves on change, or one inline rename field. They have no submit and nothing to
validate.

## What to flag in review

- A component holding several field values in `useState` and submitting them together.
- A `validate…` function, error map or `showErrors` flag beside form inputs.
- `TextField` / `Select` / `Switch` / pickers wired as form fields with their own `error`
  or `helperText`.
- Required, length, pattern or conditional rules written in code that the schema could
  hold.
- An `…En` / `…Fr` property pair, or its `required` / `dependencies`, written out
  instead of built with `languagePair`.
