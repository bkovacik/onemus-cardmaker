onemus-cardmaker scrapes a google doc and outputs cards.

# Installation
Grab the sourcecode and run
```
bundle install
```

Note that at the time of writing, rmagick DOES NOT work with ImageMagick 7! Be sure to grab the right version.

You will need to copy your config.json.base to config.json and fill it out with the authorization that you get from the [google_drive gem authorization](https://github.com/gimite/google-drive-ruby/blob/master/doc/authorization.md)

If you are running on Windows, you might have some SSL errors (Mac might too but the solution to that is to rebuild Ruby). I was able to solve my errors by pointing to a "cert.pem", available as "cacert.pem" in several places. The only one that actually worked for me was the one found by installing msys64 and looking in `/usr/ssl`.
You can set `SSL_CERT_FILE` to the cert.pem found in msys/usr/ssl and `SSL_CERT_DIR` to the certs directory found there as well.

# Reference

`align` - Text alignment (left, center, right)

`color` - Name of color template. Defined in a different yaml whose roots are globals and aspects. Globals are the same regardless, aspects change based on aspect:
  ```
    globals:
      border: '#000'
      none: '#0000'

    aspects:
      n:
        name: anger
        color:
          base: '#911'
          text: '#000'
  ```
`combine` - How the field is combined with the fields underneath

`crop` - Whether to crop to size. Resizes otherwise

`font` - Font of the text

`image` - Image for image/icon type fields

`images` - character to match: image. Used in aspect\_icon

`poly-mask` - Apply an \*gon mask to the field

`rotate` - Degrees the field is rotated

`round` - How much the corners are rounded (more is more round)

`side` - Length of a side (used with \*gon type)

`sizex` - Width

`sizey` - Height

`textsize` - Text size

`tile` - Is the image tiled? Defaults to `false`

`tilex` - Width of each tile if `tile` is `true`

`tiley` - Height of each tile if `tile` is `true`

`type` - Type of the component
  - *aspect\_icon* - Like an `icon`, but changes the icon based on the aspect of the card
  - _\*gon_ - Paints a \*-sided regular polygon
  - *icon* - Paints a static image
  - *image* - Paints a card-dependent image
  - *rect* - Paints a rectangle
  - *rounded* - Paints a rectangle with rounded border
  - *static* - Paints static text. This text should be defined in a different yaml whose root is `texts`
  - *text* - Paints card-dependent text

`x` - X position of the component

`y` - Y position of the component

`z-index` - Stacking order of the field
