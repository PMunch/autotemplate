import jester, autotemplates

type
  Information = object
    test: string

loadTemplates("templates")

routes:
  get "/":
    resp indexRaw
  post "/clicked":
    let info = Information(test: "Hello world")
    resp info.toHtml
