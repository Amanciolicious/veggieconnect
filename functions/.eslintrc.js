module.exports = {
  env: {
    browser: true,
    es6: true,
    node: true,
  },
  extends: [
    'eslint:recommended',
    'google',
  ],
  parserOptions: {
    ecmaVersion: 2018,
  },
  rules: {
    'no-restricted-globals': ['error', 'name', 'length'],
    'prefer-arrow-callback': 'error',
    'quotes': ['error', 'single', { 'allowTemplateLiterals': true }],
    'max-len': ['error', { 'code': 120 }],
    'indent': ['error', 2],
    'object-curly-spacing': ['error', 'always'],
    'require-jsdoc': 'off',
    'valid-jsdoc': 'off',
    'linebreak-style': 'off',
  },
  overrides: [
    {
      files: ['**/*.spec.*'],
      env: {
        mocha: true,
      },
      rules: {},
    },
  ],
  globals: {},
};
