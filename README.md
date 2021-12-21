# Simple auto-template experiment
Recently I've come across the combination of PicoCSS and HTMX (through this
tutorial: https://arhamjain.com/2021/11/22/nim-simple-chat.html). I've been
looking for ways to rewrite the Nim playground lately, and I really like this
idea. However I want to separate the HTML logic and the server code and not have
HTML be generated inside the server code. This is partially just to keep the
code clean, but also to help peoples ability to contribute to the project.

This repository is a simple experiment with automatically creating templates for
types in Nim, and a small example on how this can be used with PicoCSS and HTMX.

The automatic template generation means that the server code code be kept
(almost) completely free of HTML generation logic, and templates can be kept
free from Nim logic. Note that all the template generation is done during
compile-time and it's only the `public` folder containing PicoCSS that needs to
be available on runtime. The `templates` folder is read and compiled into the
binary, so changing these while the server runs won't change anything (and the
server can be deployed without this folder entirely).

## Other avenues
Another thing I'm considering is to have the entire site be one HTML file with
some special annotations and then have Nim read that HTML file and extract the
templates (and potentially replace them with HTMX tags to fetch the content).
This would mean that it would be easier to preview the website as it can simply
be opened in the browser to view the dummy content. But this poses other
challenges and I'm not sure it's worth the hassle at this point in time.
