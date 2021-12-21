import macros, os, with, templates

macro isType(x: typed): bool =
  let t = x.getType
  if t.kind == nnkBracketExpr and t[0].repr == "typeDesc":
    return newLit(true)
  else:
    return newLit(false)

macro loadTemplates*(path: static[string]): untyped =
  result = newStmtList()
  for file in path.walkDir:
    if file.kind == pcFile:
      let (dir, name, ext) = file.path.splitFile
      if ext == ".html":
        let
          typeIdent = newIdentNode(name)
          rawIdent = newIdentNode(name & "Raw")
          content = readFile(file.path)
          templateString = nnkCallStrLit.newTree(
            newIdentNode("html"),
            newStrLitNode(content))
        result.add quote do:
          const `rawIdent`* = `content`
          when isType(`typeIdent`):
            proc toHtml*(x: `typeIdent`): string =
              with x:
                tmpli `templateString`

