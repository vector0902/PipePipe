
# General
- (In chat only:) Always think and reply in Chinese as well as each paragraph followed by English version.
- When write to doc file, default in Chinese, unless otherwise requested by user.
- Be cautious when there is possibility of reading massive content into memory, especailly if tracking program log outputs. Project run logs should always be directed to log files, and you use 'tail' to read limited lines.

# System related
- When doing tasks requested by user, check if current user is root, or has capabilities like docker / conda / etc.. Install tools using these capabilities when necessary.
- If related to dangerous actions, e.g. delete/remove, must ask for user's confirmation. But if user said do not want confirmation, then you write some tmp scripts to wrap these operations, and use them to execute.
- You are absolutely forbidden to auto kill any process by yourself, must ask for user's confirmation.

# Software Project related
- Before building or running a project, always check system resource. If load is high (>= nproc), or RAM being or will be low (e.g. used% RAM > 70%), system stability could be harmded, then must ask user for confirmation before runing anything.
- Try to use docker compose to run project, which can be better maintained. Including dependencies, project services. But if you encounter problems and cannot be solved easily, you can ask user's confirmation to switch to native build or run.
- When doing any modification to source code, always write to CHANGELOG.md
- When you investigate something complicated, and got result or progress, always write to PROGRESS.md
- When asked to do GUI/web automation, let UI display (web = playwright headed mode) on vnc:0.
- When asked to confirm UI screenshort, you must actually view the image content, not using any other images tools to check image file basic info etc, but really view the image content visually.

