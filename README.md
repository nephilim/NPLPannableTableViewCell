NPLPannableTableViewCell
========================

## Notice

Horizontally pannable UITableViewCell which originally stems from a iOS zoomable/pannable tableview project. This a currently working project(internally, version 0.6), however needs lots of stuff such as documentation, code polishing, etc to be delivered.

## Overview

To be documented

## How to set your project workspace

1. Clone NPLPannableTableViewCell to the workspace folder, or add it as a submodule(git submodule add) if you're using git.[^1]
2. Add downloaded NPLPannableTableViewCell project to your Xcode workspace.[^2] Use **"Add Files To ${WORKSPACE_NAME}"** menu on navigator.
3. Click your application project in Xcode, select target, and go to **"Build Phases"** tab. In the **"Link Binary With Libraries"** section, add **libNPLPannableTableViewCell.a** in the list.
4. Now, go to **"Build Settings"** tab. In the **"Search Paths"** section, add path for NPLPannableTableViewCell's header files to **"User Header Search Paths"**. It will be a bit more convenient to use relative path with ${SRCROOT} placeholder like the following.

        ${SRCROOT}/../NPLPannableTableViewCell/NPLPannableTableViewCell

5. Add **QuartzCore.framework** to your application project. Then, it's ready.

## Sample Project

[Link to sample project](https://github.com/nephilim/NPLPannableTableViewCell-Sample)

## Footnotes

[^1]: If you want a stable release, checkout master branch. Develop branch is literally for development. FYI, I'm using git flow.

[^2]: In the Xcode workspace you made, there will be at least two child projects. One is NPLPannableTableViewCell that you've just downloaded from this site, and the other is a project for your application which will use NPLPannableTableViewCell as a library.
