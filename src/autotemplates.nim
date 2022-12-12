## This module implements a small macro to automatically load templates from
## files based on Nim types. The way it works is fairly simple, you give it a
## folder and every file in that folder on the form ``Filename.extension`` will
## create a procedure ``proc toExtension(argument: Filename): string``. So a
## simple example of:
##
## .. code-block:: nim
##
##   import autotemplates
##
##   type Person = object
##     name: string
##     age: int
##
##   loadTemplates("templates")
##   echo Person(name: "Peter", age: 29).toHtml
##
## With a file like this in ``templates/Person.html``:
##
## .. code-block:: html
##
##   <p>$name is $age years old!</p>
##
## Will simply output ``<p>Peter is 29 years old!</p>``. Of course if the object
## has fields which themselves have templates defined for them these will be
## called automatically (including ``toExtension`` procs of the same signature
## but written by hand). The module also offers a
## ``proc to(x: auto, kind: string): string`` which will dynamically select the
## template to use based on the ``kind`` argument. This means that if you have
## for example a route in a web-server which can return either HTML or e.g. RSS
## you can simply pass "html" or "rss" into the ``to`` procedure and it will
## layout your object with the correct template.
##
## The templating language used currently is
## `onionhammer/nim-templates <https://github.com/onionhammer/nim-templates>`_,
## but more options might be added in the future.
##
## For a more in-depth example have a look at ``examples/server.nim``

import macros, os, with, templates, strutils, tables, sets

var typeMapping {.compileTime.}: Table[string, seq[tuple[tmpl: string, prc: NimNode]]]

macro isTypeMacro(x: typed): bool =
  return newLit(x.getType.typeKind == ntyTypeDesc)

template isType(x: untyped): bool =
  when declared(x):
    isTypeMacro(x)
  else:
    false

macro toMacro(x: typed, kind: string): string =
  var name = x.getType.repr
  result = quote do:
    let kind = `kind`
    case kind:
    else: raise newException(KeyError, "No template registered for type " & `name` & " and extension " & kind)
  for (tmpl, toProc) in typeMapping[name]:
    result[1].insert 1, nnkOfBranch.newTree(newLit(tmpl), nnkCall.newTree(toProc, x))

proc to*(x: auto, kind: string): string =
  ## Selects the procedure to use for formatting dynamically and formats `x`
  ## using this formatting procedure.
  bind toMacro
  toMacro(x, kind)

var defs {.compileTime.}: HashSet[string]
macro generateTemplate(typedef: typed, toIdent, argument: untyped, templateString: string, filetype, filename: static[string]) =
  let typeImpl = typedef.getImpl
  typeMapping.mgetOrPut(typedef.getType[1].repr, @[]).add (filetype, toIdent)
  result =
    if typeImpl[2].kind in {nnkObjectTy, nnkTupleTy}:
      let identDefs = if typeImpl[2].kind == nnkObjectTy: typeImpl[2][2] else: typeImpl[2]
      var dollarOverrides = newStmtList(quote do:
        proc dollarShim(x: auto): string =
          when compiles(`toIdent`(x)):
            `toIdent`(x)
          else:
            $x)
      for identDef in identDefs:
        if identDef.repr in defs: break
        defs.incl identDef.repr
        let
          def = identDef[1]
          dollar = newIdentNode("$")
        dollarOverrides.add quote do:
          proc `dollar`(x: `def`): string =
            dollarShim(x)
      quote do:
        `dollarOverrides`
        with `argument`:
          tmpli `templateString`
    else:
      let lowercase = newIdentNode(typeImpl[0].strVal.toLowerAscii)
      quote do:
        var `lowercase` = `argument`
        tmpli `templateString`

macro loadTemplates*(path: static[string]): untyped =
  ## This is the main macro of this module. Reads every file in `path` and
  ## creates procedures to template an object based on that file. The name of
  ## the file is the name of the type it applies to, and the extension is the
  ## template specifier to use. For example a file `Filename.extension` will
  ## create a procedure `proc toExtension(argument: Filename): string`. The
  ## templating language used is https://github.com/onionhammer/nim-templates.
  var
    forwardDecls = newStmtList()
    implementations = newStmtList()
  if not dirExists path:
    error: "Folder \"" & path & "\" does not exist"
  for file in path.walkDir:
    if file.kind == pcFile:
      let
        filename = file.path
        (_, name, ext) = filename.splitFile
        typeIdent = newIdentNode(name)
        content = readFile(file.path)
        filetype = ext.replace(".", "")
        toIdent = newIdentNode("to" & filetype)
        templateString = newStrLitNode(content)
        argument = newIdentNode("argument")
      forwardDecls.add quote do:
        when isType(`typeIdent`):
          proc `toIdent`*(`argument`: `typeIdent`): string
      implementations.add quote do:
        when isType(`typeIdent`):
          proc `toIdent`*(`argument`: `typeIdent`): string =
            generateTemplate(`typeIdent`, `toIdent`, `argument`, `templateString`, `filetype`, `filename`)
  result = quote do:
    `forwardDecls`
    `implementations`
  #echo result.repr
