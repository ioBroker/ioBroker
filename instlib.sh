# ------------------------------
# functions
# ------------------------------

# This is: https://raw.githubusercontent.com/ArneDoe/ioBroker/instlib.sh

# test function of the library
function libtestfunction() {
  return "ok";
  local retval='ok'
  echo "$retval"
}

echo "library: loaded"
