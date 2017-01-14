onemus-cardmaker scrapes a google doc and outputs cards.

#Installation
Grab the sourcecode and run
```
bundle install
```

Note that at the time of writing, rmagick DOES NOT work with ImageMagick 7! Be sure to grab the right version.

You will need to copy your config.json.base to config.json and fill it out with the authorization that you get from the [google_drive gem authorization](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md)

If you are running on Windows, you might have some SSL errors (Mac might too but the solution to that is to rebuild Ruby). I was able to solve my errors by pointing to a "cert.pem", available as "cacert.pem" in several places. I had to rename to cert.pem and point `SSL_CERT_FILE` to it.
