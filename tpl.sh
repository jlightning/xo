#!/bin/bash

# run after changing any template file

go-bindata \
  -pkg tplbin \
  -prefix templates/ \
  -o tplbin/templates.go \
  -ignore .go$ \
  -ignore .swp$ \
  -nometadata \
  -nomemcopy templates/*.tpl
