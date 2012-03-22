##################################################################
# Define opencpu-server servers
# NOTE: we assume that all backends share the same R object store.
#

backend cpu1 {
  .host = "127.0.0.1";
  .port = "80";
  .max_connections = 20;
  .probe = {
    .url = "/R";
    .interval = 30s;
    .timeout = 2s;
    .window = 5;
    .threshold = 3;
  }
}

#Fake second backend that is always down :-)
backend cpu2 {
  .host = "123.123.123.123";
  .port = "80";
  .max_connections = 20;
  .probe = {
    .url = "/R";
    .interval = 30s;
    .timeout = 2s;
    .window = 5;
    .threshold = 3;
  }
}

director cpu_director round-robin {
  {
    .backend = cpu1;
  }
  {
    .backend = cpu2;
  }
}

sub vcl_recv {

  # The actual OpenCPU R backend it set here
  set req.backend = cpu_director;

  # We only cache on /R/
  if ( req.url ~ "^/R/" ) {
    unset req.http.Cookie;
  } else {
    return (pipe);
  }

  # Weird methods are directly piped through
  if (req.request != "GET" &&
    req.request != "HEAD" &&
    req.request != "PUT" &&
    req.request != "POST" &&
    req.request != "TRACE" &&
    req.request != "OPTIONS" &&
    req.request != "DELETE") {
    return (pipe);
  }

  # GET, POST and HEAD requests are cached. Others are passed.
  if (req.request != "GET" && 
    req.request != "HEAD" && 
    req.request != "POST") {
    return (pass);
  }
  
  # Force fresh content (F5 button)
  if (req.http.Cache-Control ~ "no-cache") {
    #insert fetch here
  }
  
  if (req.http.Cache-Control ~ "max-age=0") {
    #insert fetch here
  }  

  # Deliver a cached response:
  return (lookup);
}

### Error handling:
sub vcl_error {
  set obj.http.Content-Type = "text/plain; charset=utf-8";
  synthetic {"No R backends available... Please try again later."};
  return (deliver);
}

### Actual fetching of the backend
sub vcl_fetch {
  # This is a bit hacky. 
  # Better would be if the backend sets cache control headers on HTTP 400 responses.
  # But that is a bit tricky with rApache.
  if ( req.url ~ "^/R/" ) {
    if ( beresp.status == 400 ) {
      set beresp.ttl = 1m;
      set beresp.http.cache-control = "public";
    }
  }
  return (deliver);
}