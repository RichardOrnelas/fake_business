function handler(event) {
  var request = event.request;
  var uri = request.uri;

  if (uri.endsWith('/')) {
    request.uri += 'index.html';
  }
  if (uri.endsWith('/terms')) {
    request.uri += '/index.html';
  }
  if (uri.endsWith('/privacy')) {
    request.uri += '/index.html';
  }
  if (uri.endsWith('/contact')) {
    request.uri += '/index.html';
  }

  return request;
}
