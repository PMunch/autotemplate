## This module implements a macro to automatically load templates from files based
## on Nim types. The way it works is fairly simple, you give it a folder and every
## file in that folder on the form ``Filename.extension`` will create a procedure
## ``proc toExtension(argument: Filename): string``. So a simple example of:
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
## For more complex types like inherited objects or case objects you need to use
## specially named folders. Take the example type:
##
## .. code-block:: nim
##
##   type
##     Person = object of RootObj
##       name: string
##       age: int
##     Programmer = object of Person
##       language: string
##
## In order to lay out a ``Person`` object you create a file called for example
## ``Person.txt`` and in that file expand the ``$self`` keyword. This will look
## for matching types in a ``Person`` directory, so if we had
## ``Person/Programmer.txt`` it would use this template. Inheriting objects of
## course have access to the parent object fields as well as their own in the
## template.
##
## To make use of case objects the system is similar, take a type like this:
##
## .. code-block:: nim
##
##   type
##     PersonKind = enum Programmer, NonProgrammer
##     Person = object
##       name: string
##       age: int
##       case kind: PersonKind
##       of Programmer:
##         programmingLanguage: string
##       of NonProgrammer:
##         naturalLanguage: string
##
## To lay this out we again need a ``Person.txt`` file for example, in this file
## we can expand the ``$kind`` field. Normally this would simply output Programmer
## or NonProgrammer, but with a folder called ``Person.kind`` and files
## ``Person.kind/Programmer.txt`` and ``Person.kind/NonProgrammer.txt`` it will
## now use either of those templates to lay out the ``kind`` field.
##
## An example of this behaviour can be found in the test in the ``tests`` folder.
##
## The templating language used currently is
## `onionhammer/nim-templates <https://github.com/onionhammer/nim-templates>`_,
## but more options might be added in the future.
##
## For a more in-depth example have a look at ``examples/server.nim`` or
## ``tests/test.nim``.

import macros, os, with, templates, strutils, tables, sets
export strutils.stripLineEnd

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

template stripEnd() = result.stripLineEnd

macro generateTemplate(typedef: typed, toIdent, argument: untyped, templateString: string, filetype, filename, path, name: static[string]): untyped =
  let typeImpl = typedef.getImpl
  typeMapping.mgetOrPut(typedef.getType[1].repr, @[]).add (filetype, toIdent)
  result =
    if typeImpl[2].kind in {nnkObjectTy, nnkTupleTy, nnkRefTy}:
      var
        dollarOverrides = newStmtList()
        caseOverrides = newStmtList()
      let
        superPath = path / name
        dollar = newIdentNode("$")
      if dirExists(superPath):
        var variants = newStmtList()
        let x = newIdentNode("x")
        for file in superPath.walkDir:
          if file.kind == pcFile:
            let
              (_, name, ext) = file.path.splitFile()
              childIdent = newIdentNode(name)
            if ext.replace(".", "") == filetype:
              variants.add quote do:
                if `x` of `childIdent`:
                  return `childIdent`(`x`).`toIdent`
        dollarOverrides.add quote do:
          proc `dollar`(`x`: `typedef`): string =
            `variants`
      let
        identDefs = case typeImpl[2].kind:
          of nnkObjectTy: typeImpl[2][2]
          of nnkRefTy: typeImpl[2][0][2]
          else: typeImpl[2]
      var defs: HashSet[string]
      for identDef in identDefs:
        if identDef.kind == nnkRecCase:
          let
            fieldName = $identDef[0][0]
            kindPath = path / name & "." & fieldName
            fieldIdent = newIdentNode(fieldName)
          if dirExists(kindPath):
            # TODO: Rewrite this to recurse into parent objects and case objects. Inspect folder for more templates
            var caseDollar = newStmtList()
            for identDef in identDef[1..^1]:
              let def = identDef[1][0][1]
              if def.repr in defs: break
              defs.incl def.repr
              dollarOverrides.add quote do:
                proc `dollar`(x: `def`): string =
                  dollarShim(x)
            for file in walkDir(kindPath):
              if file.kind == pcFile:
                let
                  enumVal = newIdentNode(file.path.splitFile.name)
                  templateString = readFile(file.path).strip(false, true)
                caseDollar.add quote do:
                  if `argument`.`fieldIdent` == `enumVal`:
                    tmpli `templateString`
            let t = quote do:
              template `fieldIdent`(): untyped =
                (proc (): string =
                  `caseDollar`
                  stripEnd
                )()
            caseOverrides.add t
          continue
        let def = identDef[1]
        if def.repr in defs: break
        defs.incl def.repr
        dollarOverrides.add quote do:
          proc `dollar`(x: `def`): string =
            dollarShim(x)
      quote do:
        with `argument`:
          block:
            `dollarOverrides`
            `caseOverrides`
            tmpli `templateString`
            stripEnd
    else:
      let lowercase = newIdentNode(typeImpl[0].strVal.toLowerAscii)
      quote do:
        var `lowercase` = `argument`
        tmpli `templateString`
        stripEnd
  #echo result.repr

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
  let path = if path.isAbsolute: path else: getProjectPath() / path
  if not dirExists path:
    error: "Folder \"" & path & "\" does not exist"
  for file in path.walkDir:
    if file.kind == pcFile:
      let
        filename = file.path
        (_, name, ext) = filename.splitFile
        typeIdent = newIdentNode(name)
        content = readFile(file.path).strip(false, true)
        filetype = ext.replace(".", "")
        toIdent = newIdentNode("to" & filetype)
        templateString = newStrLitNode(content)
        argument = newIdentNode("self")
      forwardDecls.add quote do:
        when isType(`typeIdent`):
          proc `toIdent`*(`argument`: `typeIdent`): string
      implementations.add quote do:
        when isType(`typeIdent`):
          proc `toIdent`*(`argument`: `typeIdent`): string =
            proc dollarShim(x: auto): string =
              when compiles(`toIdent`(x)):
                `toIdent`(x)
              else:
                $x
            {.line: (`filename`, 0).}:
              generateTemplate(`typeIdent`, `toIdent`, `argument`, `templateString`, `filetype`, `filename`, `path`, `name`)
    if file.kind == pcDir and not file.path.contains('.'):
      forwardDecls.add newCall(newIdentNode("loadTemplates"), newLit(file.path))
  result = quote do:
    `forwardDecls`
    `implementations`
  #echo result.repr
