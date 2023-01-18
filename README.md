
**This is a test branch for <https://bitbucket.org/haukex/file-replace/src/master/>**

This branch is for creating a minimal test case for <https://github.com/Perl/perl5/issues/20207>

```
$ Porting/bisect.pl --start=v5.36.0 --end=v5.37.5 -- ./perl -Ilib /path/to/tie_handle_argv_bug.t
...

80c1f1e45e8ef8c27d170fae7ade41971fe20218 is the first bad commit
commit 80c1f1e45e8ef8c27d170fae7ade41971fe20218
Author: Tony Cook <tony@develop-help.com>
Date:   Tue Aug 16 15:52:04 2022 +1000

    only clear the stream error state in readline() for glob()

    This would previously clear the stream error state in any case
    where sv_gets() failed and the error state was set.

    This included normal files, which meant that the fact that an error
    occurred was no longer reflected in the stream state.

    For reads from ARGV this was a no-op, since nextargv() re-opens the
    input stream by calling do_open6() which closes the old input stream
    silently.

    For glob() (and really only for miniperl, since File::Glob is used for
    a full perl) leaving the stream in an error state could be confusing
    for the error reporting done when do_close() fails, since it would
    fail if the stream has an error state, but we report it as the
    underlying pclose() failing due to the child process failing in some
    way.

    Since this now leaves the error state on the stream, the close()
    calls in the test updated by this commit would fail, changing its
    output.  Since the result of those closes didn't seem related
    to the purpose of the test, I changed it not throw an error on
    either close() failing.

 pp_hot.c              | 9 +++++++--
 t/lib/warnings/pp_hot | 4 ++--
 2 files changed, 9 insertions(+), 4 deletions(-)
```

