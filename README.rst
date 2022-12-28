Autotemplates
-------------

This module implements a macro to automatically load templates from files based
on Nim types. The way it works is fairly simple, you give it a folder and every
file in that folder on the form ``Filename.extension`` will create a procedure
``proc toExtension(argument: Filename): string``. So a simple example of:

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

For more complex types like inherited objects or case objects you need to use
specially named folders. Take the example type:

.. code-block:: nim

  type
    Person = object of RootObj
      name: string
      age: int
    Programmer = object of Person
      language: string

In order to lay out a ``Person`` object you create a file called for example
``Person.txt`` and in that file expand the ``$self`` keyword. This will look
for matching types in a ``Person`` directory, so if we had
``Person/Programmer.txt`` it would use this template. Inheriting objects of
course have access to the parent object fields as well as their own in the
template.

To make use of case objects the system is similar, take a type like this:

.. code-block:: nim

  type
    PersonKind = enum Programmer, NonProgrammer
    Person = object
      name: string
      age: int
      case kind: PersonKind
      of Programmer:
        programmingLanguage: string
      of NonProgrammer:
        naturalLanguage: string

To lay this out we again need a ``Person.txt`` file for example, in this file
we can expand the ``$kind`` field. Normally this would simply output Programmer
or NonProgrammer, but with a folder called ``Person.kind`` and files
``Person.kind/Programmer.txt`` and ``Person.kind/NonProgrammer.txt`` it will
now use either of those templates to lay out the ``kind`` field.

An example of this behaviour can be found in the test in the ``tests`` folder.

The templating language used currently is
`onionhammer/nim-templates <https://github.com/onionhammer/nim-templates>`_,
but more options might be added in the future.

For a more in-depth example have a look at ``examples/server.nim`` or
``tests/test.nim``.
