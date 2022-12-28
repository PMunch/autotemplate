import autotemplates

type
  OtherObj = tuple[field: string]
  Parent = object of RootObj
    some: int
  TestKinds = enum One, Two
  TestKinds2 = enum Three, Four
  Test = object of Parent
    case kind: TestKinds
    of One:
      oneField: int
    of Two:
      twoField: float
    case kind2: TestKinds2
    of Three:
      threeField: string
    of Four:
      fourField: char
    field: string
    field2: OtherObj

loadTemplates("templates")

let data = Test(some: 42, field: "Hello world", field2: (field: "Test"), kind: One, oneField: 100)

assert data.Parent.toTxt == """This is the parent super duper template:
This is a field: Hello world
This should trigger an error: nonexistant
This is the inner object: (field: "Test")
This is case One:
100 -> 42
Three"""
