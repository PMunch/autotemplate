import macros, os, with, templates, strutils

macro isType(x: typed): bool =
  return newLit(x.getType.typeKind == ntyTypeDesc)

macro generateTemplate(typedef: typed, toIdent, argument: untyped, templateString: string) =
  let typeImpl = typedef.getImpl
  result =
    if typeImpl[2].kind in {nnkObjectTy, nnkTupleTy}:
      let identDefs = if typeImpl[2].kind == nnkObjectTy: typeImpl[2][2] else: typeImpl[2]
      var dollarOverrides = newStmtList(quote do:
        proc tt(x: auto): string =
          when compiles(`toIdent`(x)):
            `toIdent`(x)
          else:
            $x)
      for identDef in identDefs:
        let
          def = identDef[1]
          dollar = newIdentNode("$")
        dollarOverrides.add quote do:
          proc `dollar`(x: `def`): string =
            tt(x)
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
  var
    forwardDecls = newStmtList()
    implementations = newStmtList()
  for file in path.walkDir:
    if file.kind == pcFile:
      let
        (_, name, ext) = file.path.splitFile
        typeIdent = newIdentNode(name)
        content = readFile(file.path)
        toIdent = newIdentNode("to" & ext.replace(".", ""))
        templateString = newStrLitNode(content)
        argument = newIdentNode("argument")
      forwardDecls.add quote do:
        when declared(`typeIdent`):
          when isType(`typeIdent`):
            proc `toIdent`*(`argument`: `typeIdent`): string
      implementations.add quote do:
        when declared(`typeIdent`):
          when isType(`typeIdent`):
            proc `toIdent`*(`argument`: `typeIdent`): string =
              generateTemplate(`typeIdent`, `toIdent`, `argument`, `templateString`)
  result = quote do:
    `forwardDecls`
    `implementations`
  #echo result.repr
