#!/usr/bin/env node
// ============================================================
// /npmcheck - 检查当前项目的 npm 依赖状态
//
// 用法:
//   /npmcheck
//   /npmcheck --outdated
// ============================================================

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const aiguibinOutputDir = process.env.AIGUIBIN_OUTPUT_DIR || '.';
const aiguibinWorkspace = process.env.AIGUIBIN_WORKSPACE || process.cwd();

console.log('==================================================');
console.log('  NPM Dependency Check');
console.log('==================================================');
console.log('');

// 检查 package.json 是否存在
const pkgPath = path.join(aiguibinWorkspace, 'package.json');
if (!fs.existsSync(pkgPath)) {
    console.log('  [INFO] No package.json found in workspace');
    console.log(`  Workspace: ${aiguibinWorkspace}`);
    process.exit(0);
}

const pkg = JSON.parse(fs.readFileSync(pkgPath, 'utf-8'));
const deps = Object.keys(pkg.dependencies || {});
const devDeps = Object.keys(pkg.devDependencies || {});

console.log(`  Package: ${pkg.name || 'unnamed'}@${pkg.version || '0.0.0'}`);
console.log(`  Dependencies: ${deps.length}`);
console.log(`  DevDependencies: ${devDeps.length}`);
console.log('');

// 检查 node_modules
const nodeModulesExists = fs.existsSync(path.join(aiguibinWorkspace, 'node_modules'));
console.log(`  node_modules: ${nodeModulesExists ? 'exists' : 'NOT FOUND'}`);

// 检查是否需要 npm install
if (!nodeModulesExists && (deps.length + devDeps.length > 0)) {
    console.log('  [WARN] Run "npm install" first');
}

// 检查过期包
const checkOutdated = process.argv.includes('--outdated');
if (checkOutdated && nodeModulesExists) {
    console.log('');
    console.log('  --- Outdated Packages ---');
    try {
        const result = execSync('npm outdated --json 2>nul', {
            cwd: aiguibinWorkspace,
            encoding: 'utf-8',
            timeout: 30000
        });
        if (result.trim()) {
            const outdated = JSON.parse(result);
            for (const [name, info] of Object.entries(outdated)) {
                console.log(`  ${name}: ${info.current} -> ${info.latest}`);
            }
        } else {
            console.log('  All packages are up to date');
        }
    } catch (e) {
        // npm outdated returns exit code 1 when packages are outdated
        try {
            const outdated = JSON.parse(e.stdout || '{}');
            for (const [name, info] of Object.entries(outdated)) {
                console.log(`  ${name}: ${info.current} -> ${info.latest}`);
            }
        } catch {
            console.log('  Unable to check outdated packages');
        }
    }
}

// 保存报告
const report = {
    package: pkg.name,
    version: pkg.version,
    dependencies: deps.length,
    devDependencies: devDeps.length,
    nodeModulesExists,
    checkedAt: new Date().toISOString()
};
const reportPath = path.join(aiguibinOutputDir, 'npmcheck_report.json');
fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
console.log(`\n  Report saved: ${reportPath}`);
