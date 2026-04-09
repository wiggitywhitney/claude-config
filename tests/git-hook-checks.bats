#!/usr/bin/env bats
# ABOUTME: Integration tests for hooks/git/checks/ — M2 native git hook check scripts
# ABOUTME: Tests commit-message, branch-protection, progress-md, and test-tiers checks

CHECKS_DIR="$BATS_TEST_DIRNAME/../hooks/git/checks"
LIB_DIR="$BATS_TEST_DIRNAME/../hooks/git/lib"

setup() {
    TMPDIR="$(mktemp -d)"
    export GIT_REPO="$TMPDIR/testrepo"
    git init "$GIT_REPO" --quiet
    git -C "$GIT_REPO" config user.email "test@test.com"
    git -C "$GIT_REPO" config user.name "Test"
    # Ensure branch is named "main" for consistent test behavior
    git -C "$GIT_REPO" symbolic-ref HEAD refs/heads/main
    touch "$GIT_REPO/.gitkeep"
    git -C "$GIT_REPO" add .gitkeep
    git -C "$GIT_REPO" commit -m "initial commit" --quiet
}

teardown() {
    rm -rf "$TMPDIR"
}

# ── commit-message.sh ─────────────────────────────────────────────────────────

@test "commit-message: allows clean commit messages" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "fix: improve error handling in parser" > "$MSGFILE"
    run "$CHECKS_DIR/commit-message.sh" "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "commit-message: blocks bare 'Claude' reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "feat: Claude reviewed this and suggested changes" > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "commit-message: blocks 'Claude Code' reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "feat: implemented with Claude Code assistance" > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "commit-message: blocks Co-Authored-By Claude attribution" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    printf 'feat: add new feature\n\nCo-Authored-By: Claude Sonnet <noreply@anthropic.com>' > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "commit-message: blocks 'Anthropic' reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "feat: generated using Anthropic API" > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "commit-message: blocks 'AI-generated' reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "fix: AI-generated test cases" > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "commit-message: allows 'claude-config' as path reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "fix: sync hook from claude-config repo" > "$MSGFILE"
    run "$CHECKS_DIR/commit-message.sh" "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "commit-message: allows 'CLAUDE.md' as file reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "docs: update CLAUDE.md workflow instructions" > "$MSGFILE"
    run "$CHECKS_DIR/commit-message.sh" "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "commit-message: allows '.claude/' path reference" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "feat: add hook to .claude/settings.json" > "$MSGFILE"
    run "$CHECKS_DIR/commit-message.sh" "$MSGFILE"
    [ "$status" -eq 0 ]
}

@test "commit-message: allows when no file argument passed" {
    run "$CHECKS_DIR/commit-message.sh"
    [ "$status" -eq 0 ]
}

@test "commit-message: error message explains the issue and fix" {
    MSGFILE="$TMPDIR/COMMIT_EDITMSG"
    echo "feat: Claude wrote this feature" > "$MSGFILE"
    run bash -c "\"$CHECKS_DIR/commit-message.sh\" \"$MSGFILE\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Rewrite"* ]] || [[ "$output" == *"without AI"* ]]
}

# ── branch-protection.sh ──────────────────────────────────────────────────────

@test "branch-protection: blocks commit to main" {
    echo "test content" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"Cannot commit directly"* ]]
}

@test "branch-protection: allows commit on feature branch" {
    git -C "$GIT_REPO" checkout -b feature/test-branch --quiet
    echo "test content" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "branch-protection: allows docs-only .md commit on main" {
    echo "# documentation" > "$GIT_REPO/docs.md"
    git -C "$GIT_REPO" add docs.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "branch-protection: allows .gitignore-only commit on main" {
    echo "node_modules/" > "$GIT_REPO/.gitignore"
    git -C "$GIT_REPO" add .gitignore
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "branch-protection: blocks mixed .md and .sh commit on main" {
    echo "# documentation" > "$GIT_REPO/docs.md"
    echo "echo hello" > "$GIT_REPO/script.sh"
    git -C "$GIT_REPO" add docs.md script.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "branch-protection: respects .skip-branching opt-out" {
    touch "$GIT_REPO/.skip-branching"
    git -C "$GIT_REPO" add .skip-branching
    echo "test content" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "branch-protection: blocks commit to master branch" {
    MASTER_REPO="$TMPDIR/masterrepo"
    git init "$MASTER_REPO" --quiet
    git -C "$MASTER_REPO" config user.email "test@test.com"
    git -C "$MASTER_REPO" config user.name "Test"
    git -C "$MASTER_REPO" symbolic-ref HEAD refs/heads/master
    touch "$MASTER_REPO/.gitkeep"
    git -C "$MASTER_REPO" add .gitkeep
    git -C "$MASTER_REPO" commit -m "initial commit" --quiet
    echo "code" > "$MASTER_REPO/code.sh"
    git -C "$MASTER_REPO" add code.sh
    run bash -c "cd \"$MASTER_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -ne 0 ]
}

@test "branch-protection: error message includes git checkout -b suggestion" {
    echo "test content" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git checkout -b"* ]]
}

@test "branch-protection: error message mentions .skip-branching opt-out" {
    echo "test content" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/branch-protection.sh\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *".skip-branching"* ]]
}

# ── progress-md.sh ────────────────────────────────────────────────────────────

@test "progress-md: allows commit when no PROGRESS.md exists" {
    echo "code" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "progress-md: allows commit when no PRD files staged" {
    touch "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add PROGRESS.md
    git -C "$GIT_REPO" commit -m "add PROGRESS.md" --quiet
    echo "code" > "$GIT_REPO/code.sh"
    git -C "$GIT_REPO" add code.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "progress-md: allows commit when PRD staged but no new checkboxes" {
    touch "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add PROGRESS.md
    git -C "$GIT_REPO" commit -m "add PROGRESS.md" --quiet
    mkdir -p "$GIT_REPO/prds"
    printf -- '- [x] already done\n- [ ] not done yet\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    git -C "$GIT_REPO" commit -m "add PRD" --quiet
    # Modify PRD text but add no new [x] lines
    printf -- '- [x] already done\n- [ ] not done yet\n\n## Notes\nSome notes.\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "progress-md: blocks when new [x] added but PROGRESS.md not staged" {
    touch "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add PROGRESS.md
    git -C "$GIT_REPO" commit -m "add PROGRESS.md" --quiet
    mkdir -p "$GIT_REPO/prds"
    printf -- '- [ ] task one\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    git -C "$GIT_REPO" commit -m "add PRD" --quiet
    # Mark task done, do NOT stage PROGRESS.md
    printf -- '- [x] task one\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"PROGRESS.md"* ]]
}

@test "progress-md: allows when new [x] added and PROGRESS.md is staged" {
    touch "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add PROGRESS.md
    git -C "$GIT_REPO" commit -m "add PROGRESS.md" --quiet
    mkdir -p "$GIT_REPO/prds"
    printf -- '- [ ] task one\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    git -C "$GIT_REPO" commit -m "add PRD" --quiet
    # Mark task done AND stage PROGRESS.md
    printf -- '- [x] task one\n' > "$GIT_REPO/prds/01-feature.md"
    echo "- Added task one" >> "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add prds/01-feature.md PROGRESS.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "progress-md: error message includes git add PROGRESS.md instruction" {
    touch "$GIT_REPO/PROGRESS.md"
    git -C "$GIT_REPO" add PROGRESS.md
    git -C "$GIT_REPO" commit -m "add PROGRESS.md" --quiet
    mkdir -p "$GIT_REPO/prds"
    printf -- '- [ ] task one\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    git -C "$GIT_REPO" commit -m "add PRD" --quiet
    printf -- '- [x] task one\n' > "$GIT_REPO/prds/01-feature.md"
    git -C "$GIT_REPO" add prds/01-feature.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/progress-md.sh\" 2>&1"
    [ "$status" -ne 0 ]
    [[ "$output" == *"git add PROGRESS.md"* ]]
}

# ── test-tiers.sh ─────────────────────────────────────────────────────────────

@test "test-tiers: always exits 0 for unknown project type" {
    # GIT_REPO has no package.json, pyproject.toml, or go.mod — unknown project type
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
}

@test "test-tiers: warns about missing tiers for node-typescript project" {
    echo '{"name": "test", "scripts": {}}' > "$GIT_REPO/package.json"
    echo '{}' > "$GIT_REPO/tsconfig.json"
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *"WARNING"* ]]
    [[ "$output" == *"unit"* ]]
}

@test "test-tiers: silent when all test tiers present" {
    echo '{"name": "test", "scripts": {"test": "vitest"}}' > "$GIT_REPO/package.json"
    echo '{}' > "$GIT_REPO/tsconfig.json"
    mkdir -p "$GIT_REPO/tests/unit" "$GIT_REPO/tests/integration" "$GIT_REPO/tests/e2e"
    echo "test('pass', () => {})" > "$GIT_REPO/tests/unit/basic.test.ts"
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"WARNING"* ]]
}

@test "test-tiers: respects .skip-integration opt-out" {
    echo '{"name": "test", "scripts": {"test": "vitest"}}' > "$GIT_REPO/package.json"
    echo '{}' > "$GIT_REPO/tsconfig.json"
    touch "$GIT_REPO/.skip-integration"
    mkdir -p "$GIT_REPO/tests/unit"
    echo "test('pass', () => {})" > "$GIT_REPO/tests/unit/basic.test.ts"
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"integration: if"* ]]
}

@test "test-tiers: respects .skip-e2e opt-out" {
    echo '{"name": "test", "scripts": {"test": "vitest"}}' > "$GIT_REPO/package.json"
    echo '{}' > "$GIT_REPO/tsconfig.json"
    touch "$GIT_REPO/.skip-e2e"
    mkdir -p "$GIT_REPO/tests/unit"
    echo "test('pass', () => {})" > "$GIT_REPO/tests/unit/basic.test.ts"
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" != *"e2e: if"* ]]
}

@test "test-tiers: warning mentions .skip-integration to suppress" {
    echo '{"name": "test", "scripts": {}}' > "$GIT_REPO/package.json"
    echo '{}' > "$GIT_REPO/tsconfig.json"
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/main abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/test-tiers.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    [[ "$output" == *".skip-integration"* ]]
}

# ── pre-commit-verify.sh ──────────────────────────────────────────────────────

@test "pre-commit-verify: exits 0 when only .md files are staged (docs-only skip)" {
    git -C "$GIT_REPO" checkout -b feature/docs --quiet
    echo "# docs" > "$GIT_REPO/notes.md"
    git -C "$GIT_REPO" add notes.md
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/pre-commit-verify.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-commit-verify: exits 0 when project has no build system" {
    git -C "$GIT_REPO" checkout -b feature/test --quiet
    echo "plain content" > "$GIT_REPO/file.txt"
    git -C "$GIT_REPO" add file.txt
    # No package.json, go.mod, etc. — detect-project.sh returns unknown with no commands
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/pre-commit-verify.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-commit-verify: exits 1 and prints ERROR when build command fails" {
    git -C "$GIT_REPO" checkout -b feature/failing-build --quiet
    mkdir -p "$GIT_REPO/.claude"
    printf '{"commands":{"build":"exit 1"}}\n' > "$GIT_REPO/.claude/verify.json"
    echo "code" > "$GIT_REPO/main.sh"
    git -C "$GIT_REPO" add .claude/verify.json main.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/pre-commit-verify.sh\" 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "pre-commit-verify: exits 0 when all verify.json phases pass" {
    git -C "$GIT_REPO" checkout -b feature/passing-build --quiet
    mkdir -p "$GIT_REPO/.claude"
    printf '{"commands":{"build":"exit 0"}}\n' > "$GIT_REPO/.claude/verify.json"
    echo "code" > "$GIT_REPO/main.sh"
    git -C "$GIT_REPO" add .claude/verify.json main.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/pre-commit-verify.sh\" 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-commit-verify: error message instructs not to add suppression annotations" {
    git -C "$GIT_REPO" checkout -b feature/bad-build --quiet
    mkdir -p "$GIT_REPO/.claude"
    printf '{"commands":{"build":"exit 1"}}\n' > "$GIT_REPO/.claude/verify.json"
    echo "code" > "$GIT_REPO/main.sh"
    git -C "$GIT_REPO" add .claude/verify.json main.sh
    run bash -c "cd \"$GIT_REPO\" && \"$CHECKS_DIR/pre-commit-verify.sh\" 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"suppression"* ]] || [[ "$output" == *"ts-ignore"* ]] || [[ "$output" == *"lint-disable"* ]]
}

# ── pre-push-verify.sh ────────────────────────────────────────────────────────

@test "pre-push-verify: exits 0 on clean project with no remote (no diff base)" {
    git -C "$GIT_REPO" checkout -b feature/clean --quiet
    echo "plain" > "$GIT_REPO/file.txt"
    git -C "$GIT_REPO" add file.txt
    git -C "$GIT_REPO" commit -m "add file" --quiet
    # No remote configured — DIFF_BASE will be empty, security check runs in repo-grep mode
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/feature/clean abc123 refs/heads/feature/clean abc123\n' | \"$CHECKS_DIR/pre-push-verify.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-push-verify: exits 0 for docs-only branch changes vs remote base" {
    BARE_REPO="$TMPDIR/bare"
    git init --bare "$BARE_REPO" --quiet
    git -C "$GIT_REPO" remote add origin "file://$BARE_REPO"
    git -C "$GIT_REPO" push -u origin main --quiet

    git -C "$GIT_REPO" checkout -b feature/docs-only --quiet
    echo "# docs" > "$GIT_REPO/guide.md"
    git -C "$GIT_REPO" add guide.md
    git -C "$GIT_REPO" commit -m "add guide" --quiet

    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/feature/docs-only abc123 refs/heads/feature/docs-only abc123\n' | \"$CHECKS_DIR/pre-push-verify.sh\" origin file://$BARE_REPO 2>&1"
    [ "$status" -eq 0 ]
}

@test "pre-push-verify: exits 1 and prints ERROR when security check fails" {
    git -C "$GIT_REPO" checkout -b feature/security-violation --quiet
    # .only( in a test file triggers the standard security check
    mkdir -p "$GIT_REPO/tests"
    echo "it.only('focused test', () => {});" > "$GIT_REPO/tests/foo.test.js"
    git -C "$GIT_REPO" add tests/foo.test.js
    git -C "$GIT_REPO" commit -m "add focused test" --quiet
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/feature/security-violation abc123 refs/heads/feature/security-violation abc123\n' | \"$CHECKS_DIR/pre-push-verify.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"ERROR"* ]]
}

@test "pre-push-verify: skips CodeRabbit review when .skip-coderabbit present" {
    git -C "$GIT_REPO" checkout -b feature/skip-cr --quiet
    touch "$GIT_REPO/.skip-coderabbit"
    echo "plain" > "$GIT_REPO/file.txt"
    git -C "$GIT_REPO" add .skip-coderabbit file.txt
    git -C "$GIT_REPO" commit -m "add file" --quiet
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/feature/skip-cr abc123 refs/heads/feature/skip-cr abc123\n' | \"$CHECKS_DIR/pre-push-verify.sh\" origin https://example.com 2>&1"
    [ "$status" -eq 0 ]
    # No CodeRabbit output expected — would only appear if CR CLI is installed and finds issues
    [[ "$output" != *"CodeRabbit Advisory"* ]]
}

@test "pre-push-verify: uses REMOTE_NAME arg to derive diff base when remote is not origin" {
    BARE_REPO="$TMPDIR/bare"
    git init --bare "$BARE_REPO" --quiet

    # Add a .only violation to main (simulates existing violation on the base branch)
    mkdir -p "$GIT_REPO/tests"
    echo "it.only('focused test', () => {});" > "$GIT_REPO/tests/base.test.js"
    git -C "$GIT_REPO" add tests/base.test.js
    git -C "$GIT_REPO" commit -m "add base test" --quiet

    # Push to 'upstream' without -u (no tracking ref, no origin remote)
    git -C "$GIT_REPO" remote add upstream "file://$BARE_REPO"
    git -C "$GIT_REPO" push upstream main --quiet

    git -C "$GIT_REPO" checkout -b feature/upstream-docs --quiet
    echo "# docs" > "$GIT_REPO/guide.md"
    git -C "$GIT_REPO" add guide.md
    git -C "$GIT_REPO" commit -m "add guide" --quiet

    # Before fix: DIFF_BASE="" (no tracking ref, no origin/main) → repo-scoped security
    #             → finds .only in base commit → exits 1
    # After fix: DIFF_BASE="upstream/main" (derived from REMOTE_NAME + stdin ref)
    #            → docs-only branch → exits 0
    run bash -c "cd \"$GIT_REPO\" && printf 'refs/heads/feature/upstream-docs abc123 refs/heads/main abc123\n' | \"$CHECKS_DIR/pre-push-verify.sh\" upstream file://$BARE_REPO 2>&1"
    [ "$status" -eq 0 ]
}

# ── detect-project.sh ─────────────────────────────────────────────────────────

@test "detect-project: yarn classic project uses yarn for fallback typecheck command" {
    PROJ="$TMPDIR/yarn-classic"
    mkdir "$PROJ"
    echo '{"name": "test", "scripts": {}}' > "$PROJ/package.json"
    echo '{}' > "$PROJ/tsconfig.json"
    touch "$PROJ/yarn.lock"
    # No .yarnrc.yml = classic Yarn

    run "$LIB_DIR/detect-project.sh" "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"typecheck": "yarn tsc --noEmit"'* ]]
}

@test "detect-project: yarn berry project uses yarn dlx for fallback typecheck command" {
    PROJ="$TMPDIR/yarn-berry"
    mkdir "$PROJ"
    echo '{"name": "test", "scripts": {}}' > "$PROJ/package.json"
    echo '{}' > "$PROJ/tsconfig.json"
    touch "$PROJ/yarn.lock"
    touch "$PROJ/.yarnrc.yml"  # presence of .yarnrc.yml = Berry/PnP

    run "$LIB_DIR/detect-project.sh" "$PROJ"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"typecheck": "yarn dlx tsc --noEmit"'* ]]
}
