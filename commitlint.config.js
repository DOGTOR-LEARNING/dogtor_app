module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',     // 新功能
        'fix',      // 修復
        'docs',     // 文檔
        'style',    // 格式
        'refactor', // 重構
        'test',     // 測試
        'chore',    // 雜務
        'ci',       // CI/CD
        'perf',     // 性能優化
        'revert'    // 回退
      ]
    ],
    'subject-max-length': [2, 'always', 100],
    'header-max-length': [2, 'always', 100]
  }
};