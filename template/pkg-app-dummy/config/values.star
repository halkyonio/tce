load("@ytt:data", "data")
load("@ytt:assert", "assert")

def validate_dummy_namespace():
  values.namespace or assert.fail("dummy namespace should be provided")
end