Autotemplates
-------------

This module implements a small macro to automatically load templates from
files based on Nim types. The way it works is fairly simple, you give it a
folder and every file in that folder on the form ``Filename.extension`` will
create a procedure ``proc toExtension(argument: Filename): string``. So a
simple example of:

.. code-block:: nim

  import autotemplates

  type Person = object
    name: string
    age: int

  loadTemplates("templates")
  echo Person(name: "Peter", age: 29).toHtml

With a file like this in ``templates/Person.html``:

.. code-block:: html

  <p>$name is $age years old!</p>

Will simply output ``<p>Peter is 29 years old!</p>``. Of course if the object
has fields which themselves have templates defined for them these will be
called automatically (including ``toExtension`` procs of the same signature
but written by hand). The module also offers a
``proc to(x: auto, kind: string): string`` which will dynamically select the
template to use based on the ``kind`` argument. This means that if you have
for example a route in a web-server which can return either HTML or e.g. RSS
you can simply pass "html" or "rss" into the ``to`` procedure and it will
layout your object with the correct template.

The templating language used currently is
`onionhammer/nim-templates <https://github.com/onionhammer/nim-templates>`_,
but more options might be added in the future.

For a more in-depth example have a look at ``examples/server.nim``
