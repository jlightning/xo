package main

//go:generate ./tpl.sh
//go:generate ./gen.sh models

import (
	"bytes"
	"crypto/sha1"
	"database/sql"
	"encoding/base64"
	"encoding/json"
	"errors"
	"fmt"
	"go/format"
	"io"
	"io/ioutil"
	"log"
	"os"
	"os/exec"
	"path"
	"sort"
	"strings"

	"github.com/alexflint/go-arg"
	"github.com/knq/snaker"
	"gopkg.in/yaml.v2"

	"github.com/xo/dburl"
	_ "github.com/xo/xoutil"

	"github.com/jlightning/xo/internal"
	_ "github.com/jlightning/xo/loaders"
	"github.com/jlightning/xo/models"
)

func main() {
	// circumvent all logic to just determine if xo was built with oracle
	// support
	if len(os.Args) == 2 && os.Args[1] == "--has-oracle-support" {
		var out int
		if _, ok := internal.SchemaLoaders["ora"]; ok {
			out = 1
		}

		fmt.Fprintf(os.Stdout, "%d", out)
		return
	}

	var err error

	// get defaults
	internal.Args = internal.NewDefaultArgs()
	args := internal.Args

	// parse args
	arg.MustParse(args)

	parseXoConfigFile(args)

	// process args
	err = processArgs(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	// open database
	err = openDB(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
	defer args.DB.Close()

	// load schema name
	if args.Schema == "" {
		args.Schema, err = args.Loader.SchemaName(args)
		if err != nil {
			fmt.Fprintf(os.Stderr, "error: %v\n", err)
			os.Exit(1)
		}
	}

	// load defs into type map
	if args.QueryMode {
		err = args.Loader.ParseQuery(args)
	} else {
		err = args.Loader.LoadSchema(args)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	// add xo
	//err = args.ExecuteTemplate(internal.XOTemplate, "xo_db", "", args)
	//if err != nil {
	//	fmt.Fprintf(os.Stderr, "error: %v\n", err)
	//	os.Exit(1)
	//}

	err = args.ExecuteTemplate(internal.RepositoryCommonTemplate, "common", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	err = args.ExecuteTemplate(internal.PaginationTemplate, "pagination", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	err = args.ExecuteTemplate(internal.PaginationSchemaTemplate, "pagination", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	err = args.ExecuteTemplate(internal.ScalarTemplate, "scalar", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	err = args.ExecuteTemplate(internal.SchemaGraphQLScalarTemplate, "scalar", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	err = args.ExecuteTemplate(internal.WireTemplate, "wire", "", args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	// output
	err = writeTypes(args)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}
}

func parseXoConfigFile(args *internal.ArgType) {
	data, err := ioutil.ReadFile("xo_config.yml")
	if err != nil {
		return
	}
	err = yaml.Unmarshal(data, &internal.XoConfig)
	if err != nil {
		return
	}
}

// processArgs processs cli args.
func processArgs(args *internal.ArgType) error {
	var err error

	// get working directory
	cwd, err := os.Getwd()
	if err != nil {
		return err
	}

	// determine out path
	if args.Out == "" {
		args.Path = cwd
	} else {
		// determine what to do with Out
		fi, err := os.Stat(args.Out)
		if err == nil && fi.IsDir() {
			// out is directory
			args.Path = args.Out
		} else if err == nil && !fi.IsDir() {
			// file exists (will truncate later)
			args.Path = path.Dir(args.Out)
			args.Filename = path.Base(args.Out)

			// error if not split was set, but destination is not a directory
			if !args.SingleFile {
				return errors.New("output path is not directory")
			}
		} else if _, ok := err.(*os.PathError); ok {
			// path error (ie, file doesn't exist yet)
			args.Path = path.Dir(args.Out)
			args.Filename = path.Base(args.Out)

			// error if split was set, but dest doesn't exist
			if !args.SingleFile {
				return errors.New("output path must be a directory and already exist when not writing to a single file")
			}
		} else {
			return err
		}
	}

	// check user template path
	if args.TemplatePath != "" {
		fi, err := os.Stat(args.TemplatePath)
		if err == nil && !fi.IsDir() {
			return errors.New("template path is not directory")
		} else if err != nil {
			return errors.New("template path must exist")
		}
	}

	// fix path
	if args.Path == "." {
		args.Path = cwd
	}

	// determine package name
	if args.Package == "" {
		args.Package = path.Base(args.Path)
	}

	// determine filename if not previously set
	if args.Filename == "" {
		args.Filename = args.Package + args.Suffix
	}

	// if query mode toggled, but no query, read Stdin.
	if args.QueryMode && args.Query == "" {
		buf, err := ioutil.ReadAll(os.Stdin)
		if err != nil {
			return err
		}
		args.Query = string(buf)
	}

	// query mode parsing
	if args.Query != "" {
		args.QueryMode = true
	}

	// check that query type was specified
	if args.QueryMode && args.QueryType == "" {
		return errors.New("query type must be supplied for query parsing mode")
	}

	// query trim
	if args.QueryMode && args.QueryTrim {
		args.Query = strings.TrimSpace(args.Query)
	}

	// escape all
	if args.EscapeAll {
		args.EscapeSchemaName = true
		args.EscapeTableNames = true
		args.EscapeColumnNames = true
	}

	// if verbose
	if args.Verbose {
		models.XOLog = func(s string, p ...interface{}) {
			fmt.Printf("SQL:\n%s\nPARAMS:\n%v\n\n", s, p)
		}
	}

	if args.EntitiesPkg == "" {
		log.Fatal("--entities-pkg: entities package is required")
	}

	return nil
}

// openDB attempts to open a database connection.
func openDB(args *internal.ArgType) error {
	var err error

	// parse dsn
	u, err := dburl.Parse(args.DSN)
	if err != nil {
		return err
	}

	// save driver type
	args.LoaderType = u.Driver

	// grab loader
	var ok bool
	args.Loader, ok = internal.SchemaLoaders[u.Driver]
	if !ok {
		return errors.New("unsupported database type")
	}

	// open database connection
	args.DB, err = sql.Open(u.Driver, u.DSN)
	if err != nil {
		return err
	}

	return nil
}

// files is a map of filenames to open file handles.

func getFileName(args *internal.ArgType, t *internal.TBuf) (string, string, string) {
	pkg := args.Package
	// determine filename
	var filename = strings.ToLower(snaker.CamelToSnake(t.Name))
	if t.TemplateType == internal.SchemaGraphQLTemplate || t.TemplateType == internal.SchemaGraphQLEnumTemplate || t.TemplateType == internal.SchemaGraphQLScalarTemplate || t.TemplateType == internal.PaginationSchemaTemplate {
		filename += ".graphql"
	} else if t.TemplateType == internal.GqlgenModelTemplate {
		filename += ".yml"
	} else if t.TemplateType == internal.WireTemplate {
		filename += ".go"
	} else if t.TemplateType == internal.ApprovalMigrationTemplate || t.TemplateType == internal.AuditLogsMigrationTemplate {
		filename += ".sql"
	} else {
		filename += args.Suffix
	}
	if t.TemplateType == internal.RepositoryTemplate || t.TemplateType == internal.IndexTemplate || t.TemplateType == internal.ForeignKeyTemplate || t.TemplateType == internal.RepositoryCommonTemplate {
		pkg = "repositories"
		filename = "repositories/" + filename
	} else if t.TemplateType == internal.SchemaGraphQLTemplate || t.TemplateType == internal.SchemaGraphQLEnumTemplate || t.TemplateType == internal.SchemaGraphQLScalarTemplate || t.TemplateType == internal.PaginationSchemaTemplate {
		pkg = "schema"
		filename = "graphql/schema/" + filename
	} else if t.TemplateType == internal.GqlgenModelTemplate {
		filename = "graphql/" + filename
	} else if t.TemplateType == internal.WireTemplate {
		pkg = "main"
	} else if t.TemplateType == internal.ApprovalMigrationTemplate || t.TemplateType == internal.AuditLogsMigrationTemplate {
		filename = "migrations/" + filename
	} else {
		pkg = "entities"
		filename = "entities/" + filename
	}
	if args.SingleFile {
		filename = args.Filename
	}
	return path.Join(args.Path, filename), filename, pkg
}

// getFile builds the filepath from the TBuf information, and retrieves the
// file from files. If the built filename is not already defined, then it calls
// the os.OpenFile with the correct parameters depending on the state of args.
func getFile(args *internal.ArgType, filename string, pkg string) (*os.File, error) {
	var buf bytes.Buffer
	var f *os.File
	var err error

	oldArgPkg := args.Package

	// default open mode
	mode := os.O_RDWR | os.O_CREATE | os.O_TRUNC

	// open file
	f, err = os.OpenFile(filename, mode, 0666)
	if err != nil {
		return nil, err
	}

	args.Package = pkg

	// file didn't originally exist, so add package header
	if args.Tags != "" {
		buf.WriteString(`// +build ` + args.Tags + "\n\n")
	}

	generatedText := "Code generated by Xo. DO NOT EDIT.\n\n"

	switch {
	case strings.HasSuffix(filename, ".go"):
		buf.WriteString("// " + generatedText)
	case strings.HasSuffix(filename, ".yml"):
		fallthrough
	case strings.HasSuffix(filename, ".graphql"):
		buf.WriteString("# " + generatedText)
	case strings.HasSuffix(filename, ".sql"):
		buf.WriteString("-- " + generatedText)
	}

	if strings.HasSuffix(filename, ".go") {
		if strings.HasSuffix(filename, "wire.go") {
			if _, err = buf.WriteString("//+build wireinject\n\npackage main"); err != nil {
				return nil, err
			}
		} else {
			// execute
			err = args.TemplateSet().Execute(f, "xo_package.go.tpl", args)
			if err != nil {
				return nil, err
			}
		}
	} else if strings.HasSuffix(filename, ".yml") {
		err = args.TemplateSet().Execute(buf, "gqlgen.yml.tpl", args)
		if err != nil {
			return nil, err
		}
	}

	args.Package = oldArgPkg

	byts, err := format.Source(buf.Bytes())
	if err != nil {
		f.Write(buf.Bytes())
	} else {
		f.Write(byts)
	}

	return f, nil
}

func hashString(data string) string {
	h := sha1.New()
	io.WriteString(h, data)
	str := base64.StdEncoding.EncodeToString(h.Sum(nil))
	return "sha1-" + str
}

type fileWrite struct {
	data                string
	filenameWithoutPath string
	pkg                 string
}

// writeTypes writes the generated definitions.
func writeTypes(args *internal.ArgType) error {
	var err error

	out := internal.TBufSlice(args.Generated)

	// sort segments
	sort.Sort(out)

	fileWriteMap := make(map[string]fileWrite)

	for _, t := range out {
		// skip when in append and type is XO
		if args.Append && t.TemplateType == internal.XOTemplate {
			continue
		}

		if t.TemplateType == internal.WireTemplate {
			continue
		}

		// check if generated template is only whitespace/empty
		bufStr := strings.TrimSpace(t.Buf.String())
		if len(bufStr) == 0 {
			continue
		}

		// get file and filename
		filename, filenameWithoutPath, pkg := getFileName(args, &t)
		fileWr := fileWriteMap[filename]
		fileWr.pkg = pkg
		fileWr.filenameWithoutPath = filenameWithoutPath

		if !args.Append || (t.TemplateType != internal.TypeTemplate && t.TemplateType != internal.QueryTypeTemplate) {
			fileWr.data += t.Buf.String()
		}

		fileWriteMap[filename] = fileWr
	}

	if fileWr, ok := fileWriteMap[path.Join(args.Path, "graphql/gqlgen.yml")]; ok {
		if fileWriteMap[path.Join(args.Path, "graphql/gqlgen.yml")], err = tryMergeGqlgenYml(args, fileWr); err != nil {
			return err
		}
	} else {
		return errors.New("gqlgen.yml not found")
	}

	cacheFile := path.Join(args.Path, "xo-lock.json")
	jsonData, _ := ioutil.ReadFile(cacheFile)
	fileHashes := make(map[string]string)
	json.Unmarshal(jsonData, &fileHashes)

	files := make(map[string]*os.File)

	for filename, fileWr := range fileWriteMap {
		hash := hashString(fileWr.data)
		if fileHashes[fileWr.filenameWithoutPath] == hash {
			continue
		}

		fmt.Println("update ", fileWr.filenameWithoutPath)

		fileHashes[fileWr.filenameWithoutPath] = hash

		f, err := getFile(args, filename, fileWr.pkg)
		if err != nil {
			return err
		}

		files[filename] = f

		_, err = io.WriteString(f, fileWr.data)
		if err != nil {
			return err
		}
	}

	jsonData, err = json.MarshalIndent(fileHashes, "", "  ")
	if err != nil {
		return err
	}

	if err = ioutil.WriteFile(cacheFile, jsonData, 0666); err != nil {
		return err
	}

	// build goimports parameters, closing files
	params := []string{"-w"}
	for k, f := range files {
		if strings.HasSuffix(f.Name(), ".go") {
			params = append(params, k)
		}

		// close
		err = f.Close()
		if err != nil {
			return err
		}
	}

	//fmt.Println("--- Repositories: ")
	//for _, v := range args.NewTemplateFuncs()["reponames"].(func() []string)() {
	//	if !strings.Contains(v, "Rlts") {
	//		fmt.Println(v)
	//	}
	//}
	//
	//fmt.Println("--- Rlts Repositories: ")
	//for _, v := range args.NewTemplateFuncs()["reponames"].(func() []string)() {
	//	if strings.Contains(v, "Rlts") {
	//		fmt.Println(v)
	//	}
	//}

	// process written files with goimports
	return exec.Command("goimports", params...).Run()
}

func tryMergeGqlgenYml(args *internal.ArgType, fileWr fileWrite) (fileWrite, error) {
	importFile := args.Path + "/graphql/gqlgen_import.yml"
	if _, err := os.Stat(importFile); err == nil {
		data, err := ioutil.ReadFile(importFile)
		if err != nil {
			return fileWrite{}, err
		}
		var value struct {
			Models map[string]struct {
				Model string
			}
		}
		err = yaml.Unmarshal(data, &value)

		var keys []string
		for k := range value.Models {
			keys = append(keys, k)
		}

		sort.Strings(keys)
		for _, k := range keys {
			v := value.Models[k]
			fileWr.data += fmt.Sprintf("  %s:\n    model: %s\n", k, v.Model)
		}
	}
	return fileWr, nil
}
