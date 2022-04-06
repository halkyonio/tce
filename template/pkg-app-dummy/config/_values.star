load("@ytt:data", "data")
load("@ytt:assert", "assert")

def validate_dummy_namespace():
  data.values.namespace or assert.fail("dummy namespace should be provided")
end

def validate_dummy():
  validate_funcs = [
    validate_dummy_namespace,
  ]
  for validate_func in validate_funcs:
     validate_func()
  end
end

#export
values = data.values

# validate dummy data values
validate_dummy()