module.exports = {
  env: {
    browser: false,
    es2021: true,
    node: true,
    mocha: true
  },
  extends: [
    'standard'
  ],
  parserOptions: {
    ecmaVersion: 'latest',
    sourceType: 'module'
  },
  rules: {
    // Allow console.log in backend applications
    'no-console': 'off',
    
    // Allow unused variables that start with underscore
    'no-unused-vars': ['error', { 'argsIgnorePattern': '^_' }],
    
    // Allow semicolons (optional)
    'semi': ['error', 'always'],
    
    // Allow trailing commas
    'comma-dangle': ['error', 'never']
  }
};
