@echo off
setlocal EnableExtensions EnableDelayedExpansion
REM git_os_standards_repo_cleaner.bat https://github.com/NREL/openstudio-standards.git https://stash.veic.org/scm/mod/openstudio-standards-veic-vtcbes.git 05a7ebbe338600738f8915135d9db94bc7c4a70e openstudio-standards-veic

echo Ensure git-filter-repo is available via Python (should list version below)
py -m git_filter_repo --version

@REM echo Display file size, branches, and tags before cleaning.
@REM @echo on
@REM git branch
@REM git tag
@REM git count-objects -vH
@REM git remote remove origin
@REM git remote add origin https://stash.veic.org/scm/mod/openstudio-standards-veic-vtcbes.git

@REM git rev-list --objects --all > temp_objects.txt


@REM REM Set the base version to screen for (default 0.4.0, or pass as %1)
@REM set "BASE=%1"
@REM if "%BASE%"=="" set "BASE=0.4.0"

@REM REM List all tags sorted by version, and delete those < BASE or containing 'rc'
@REM echo Deleting tags before %BASE% or containing 'rc'...
@REM for /f "usebackq delims=" %%T in (`git tag --sort=version:refname`) do (
@REM     set "TAG=%%T"
@REM     REM Remove leading 'v' if present for comparison
@REM     set "TAG_CMP=!TAG!"
@REM     if "!TAG_CMP:~0,1!"=="v" set "TAG_CMP=!TAG_CMP:~1!"
@REM     set "DELETE_TAG=0"
@REM     echo !TAG! | findstr /I "rc" >nul
@REM     if !errorlevel! == 0 set "DELETE_TAG=1"
@REM     if !DELETE_TAG! == 0 if /I "!TAG_CMP!" LSS "%BASE%" set "DELETE_TAG=1"
@REM     if !DELETE_TAG! == 1 (
@REM         echo Deleting tag: !TAG!
@REM         git tag -d "!TAG!"
@REM     )
@REM )
@REM echo Done.

@REM echo Permanently remove specific paths (and their history):
@REM py -m git_filter_repo --path data/weather --path test --invert-paths --force

@REM echo Post-rewrite gc to actually save space
@REM git reflog expire --expire=now --all
@REM git gc --prune=now --aggressive

echo get new repo size
git count-objects -vH
@REM nice at 745 MB!

echo Get commit hash for v0.4.0
git rev-list -n 1 v0.4.0

echo Remove old commit history before tag v0.4.0 (957f30481)
git replace --graft 957f304811b9783dfcf72b659cc51fe5bfe13e02
py -m git_filter_repo --force
@REM echo Post-rewrite gc to actually save space
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo get new repo size
git count-objects -vH
@REM echo push to bitbucket
@REM git push -u --force origin master

@REM echo Done.
