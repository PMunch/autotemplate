import jester, re, json
import "../src/autotemplates"

# First we declare the types we want to be convertible
type
  Information = object
    info: Something
  Something = string
  InfoTuple = tuple[snippetId: int, info: Information]
  TestSeq = seq[string]

# We can also specify custom `to` procedures. Note that these won't be detected
# by the `to` procedure, but they will automatically be invoked by any type
# which contains this type as a field.
proc toHtml(x: Something): string =
  "This is something: " & $x

# Load templates from a couple different folders
loadTemplates("templates")
loadTemplates("rssTemplates")

settings:
  port = Port(5050)

# Set up some simple jester routes
routes:
  get "/":
    # Basic stuff like this still lives in the normal "public" folder
    redirect "index.html"
  post "/clicked":
    # Generate a response object
    let info = Information(info: "Hello world")
    # And convert it to HTML based on the `Information.html` template file.
    resp info.toHtml
  get re"^\/information\.(html|rss)$":
    let info = (snippetId: 42, info: Information(info: "Hello world"))
    # We can also use `to` to take the filetype to convert to dynamically. Note
    # that the logic for generating the info object is always the same, we just
    # format the object differently.
    resp info.to(request.matches[0])
  get "/testseq":
    # In order to have templates for built-in data structures or other things
    # like that you need to create a type alias:
    resp TestSeq(@["Hello", "world"]).toHtml
