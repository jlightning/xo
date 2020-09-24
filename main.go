package main

//go:generate ./tpl.sh
//go:generate ./gen.sh models

import (
	"github.com/jlightning/xo/cmd"
	_ "github.com/xo/xoutil"

	_ "github.com/jlightning/xo/loaders"
)

func main() {
	cmd.Excecute()
}
