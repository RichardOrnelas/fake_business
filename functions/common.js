function basename(filename) {
  var i = filename.lastIndexOf('/');
  return (i < 0) ? '' : filename.substr(i);
}

function getExtension(filename) {
  var base = basename(filename);
  var i = base.lastIndexOf('.');
  return (i < 0) ? '' : base.substr(i);
}

var NON_EXT_FILES = [
  "apple-app-site-association",
  "apple-developer-merchantid-domain-association",
];

function shouldReplacePath(uri) {
  return !getExtension(uri) && !uri.includes("apple-app-site-association") && !uri.includes("apple-developer-merchantid-domain-association")
}

function buildExperimentCookie(value) {

  var attributes = []
  attributes.push("Secure")
  attributes.push("Path=/")

  if(EXPERIMENTS_COOKIE_TTL > 0) {
    attributes.push(`Max-Age=${EXPERIMENTS_COOKIE_TTL}`)
  }

  attributes.push("SameSite=None")

  return {
    value: value ? "1" : "0",
    attributes: attributes.join("; ")
  }
}