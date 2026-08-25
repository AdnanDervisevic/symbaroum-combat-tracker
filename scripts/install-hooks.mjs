// Point git at the hooks committed in .githooks/.
//
// Git will not run hooks from a tracked directory on its own -- .git/hooks is
// not version controlled, which is why hooks usually get set up once by hand and
// then never exist on anybody else's clone. `core.hooksPath` fixes that, and npm
// runs this from `prepare` so a plain `npm install` is the whole setup.
//
// Every failure here is non-fatal on purpose: installing dependencies from a
// tarball, in CI, or anywhere without git should not fail because a convenience
// could not be wired up.

import { execFileSync } from 'node:child_process'
import { existsSync } from 'node:fs'

const HOOKS_DIR = '.githooks'

try {
  if (!existsSync('.git')) {
    // Not a git checkout -- an npm install of the package, most likely.
    process.exit(0)
  }

  execFileSync('git', ['config', 'core.hooksPath', HOOKS_DIR], { stdio: 'ignore' })

  // Windows checkouts do not carry the executable bit; git needs to be told.
  try {
    execFileSync('git', ['update-index', '--chmod=+x', `${HOOKS_DIR}/pre-commit`], {
      stdio: 'ignore',
    })
  } catch {
    // Only relevant when the file is already tracked; harmless otherwise.
  }

  console.log(`hooks: core.hooksPath -> ${HOOKS_DIR} (skip once with 'git commit --no-verify')`)
} catch (err) {
  console.warn('hooks: could not set core.hooksPath, continuing anyway.', err?.message ?? err)
}
