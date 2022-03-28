import jester, autotemplates, re

type
  Information = object
    test: Something
  Something = string
  InfoTuple = tuple[test: int, field: Information]

proc toHtml(x: Something): string =
  "This is something: " & $x

loadTemplates("src/templates")

routes:
  get "/":
    redirect "index.html"
  post "/clicked":
    let info = (test: 42, field: Information(test: "Hello world"))
    resp info.toHtml
  get re"^\/information(\.html|\.rss)?$":
    echo request.matches
    let info = (test: 42, field: Information(test: "Hello world"))
    resp info.toHtml
  get re"/\(foobar\)/(.+)/":
    echo request.matches
    resp request.matches[0]

