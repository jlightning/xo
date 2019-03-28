{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $table := (schema .Table.TableName) -}}
{{- $tableVar := .Table }}
{{- $primaryKey := .PrimaryKey }}
{{- if .Comment -}}
// {{ .Comment }}
{{- else -}}
// {{ .Name }} represents a row from '{{ $table }}'.
{{- end }}
type {{ .Name }} struct {
{{- range .Fields }}
    {{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInType }}
    {{- if and .Col.IsEnum (ne .Col.NotNull true) }}
        {{ .Name }} *{{ retype .Type }} `json:"{{ .Col.ColumnName }}" db:"{{ .Col.ColumnName }}"` // {{ .Col.ColumnName }}
    {{- else }}
	    {{ .Name }} {{ retype .Type }} `json:"{{ .Col.ColumnName }}" {{ if ne .Col.IsVirtualFromConfig true }}db:"{{ .Col.ColumnName }}"{{ end }}` // {{ .Col.ColumnName }}
    {{- end }}
    {{- end }}
{{- end }}
}

type {{ .Name }}Filter struct {
{{- range .Fields }}
    {{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInFilter }}
	{{ .Name }} FilterOnField
	{{- end }}
{{- end }}
    Wheres []sq.Sqlizer
    Joins []sq.Sqlizer
    LeftJoins []sq.Sqlizer
    GroupBys []string
    OrderBys []string
}

{{- $typeName := .Name }}

func (f *{{ $typeName }}Filter) NewFilter() interface{} {
    if f == nil {
        return &{{ $typeName }}Filter{}
    }
    return f
}

func (f *{{ $typeName}}Filter) IsNil() bool {
    return f == nil
}

{{- range .Fields }}
{{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInFilter }}
func (f *{{ $typeName }}Filter) Add{{ .Name }}(filterType FilterType, v interface{}) {
    f.{{ .Name }} = append(f.{{ .Name }}, map[FilterType]interface{}{filterType: v})
}
{{- end }}
{{- end }}

func (f *{{ $typeName }}Filter) Where(v sq.Sqlizer) *{{ $typeName }}Filter {
    f.Wheres = append(f.Wheres, v)
    return f
}

func (f *{{ $typeName }}Filter) Join(j sq.Sqlizer) *{{ $typeName }}Filter {
    f.Joins = append(f.Joins, j)
    return f
}

func (f *{{ $typeName }}Filter) LeftJoin(j sq.Sqlizer) *{{ $typeName }}Filter {
    f.LeftJoins = append(f.LeftJoins, j)
    return f
}

func (f *{{ $typeName }}Filter) GroupBy(gb string) *{{ $typeName }}Filter {
    f.GroupBys = append(f.GroupBys, gb)
    return f
}

func (f *{{ $typeName }}Filter) OrderBy(ob string) *{{ $typeName }}Filter {
    f.OrderBys = append(f.OrderBys, ob)
    return f
}

func (f *{{ $typeName }}Filter) Hash() (string, error) {
    var err error
    var hash string
    if f == nil {
        return "", nil
    }
    h := md5.New()
    list := []struct{
        filter FilterOnField
        name string
    }{
        {{- range .Fields }}{{ if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInFilter }}{ filter: f.{{.Name}}, name: "{{ .Name }}" },{{end}}{{- end}}
    }
    for _, item := range list {
        hash, err = item.filter.Hash()
        if err != nil {
            return "", err
        }
        if _, err = io.WriteString(h, item.name+" -> "+hash); err != nil {
            return "", err
        }
    }
    if f.Wheres != nil {
         for _, item := range f.Wheres {
             query, args, err := item.ToSql()
             if err != nil {
                 return "", err
             }
             if _, err = io.WriteString(h, query+" -> "+fmt.Sprintf("%v", args)); err != nil {
                 return "", err
             }
         }
    }
    if f.Joins != nil {
         for _, item := range f.Joins {
             query, args, err := item.ToSql()
             if err != nil {
                 return "", err
             }
             if _, err = io.WriteString(h, query+" -> "+fmt.Sprintf("%v", args)); err != nil {
                 return "", err
             }
         }
    }
    if f.LeftJoins != nil {
         for _, item := range f.LeftJoins {
             query, args, err := item.ToSql()
             if err != nil {
                 return "", err
             }
             if _, err = io.WriteString(h, query+" -> "+fmt.Sprintf("%v", args)); err != nil {
                 return "", err
             }
         }
    }
    if f.GroupBys != nil {
        if _, err = io.WriteString(h, "groupBy -> "+fmt.Sprintf("%v", f.GroupBys)); err != nil {
             return "", err
         }
    }
    if f.OrderBys != nil {
        if _, err = io.WriteString(h, "orderBy -> "+fmt.Sprintf("%v", f.OrderBys)); err != nil {
            return "", err
        }
    }
    return fmt.Sprintf("%x", h.Sum(nil)), nil
}

type {{ .Name }}Create struct {
{{- range .Fields }}
    {{- if and (or (ne .Col.ColumnName $primaryKey.Col.ColumnName) $tableVar.ManualPk) (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") }}
    {{- if and (or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInCreate) (ne .Col.DisableForCreate true) }}
	{{ .Name }} {{- if .Col.NotNull}} {{ retype .Type }}{{ else }} {{retypeNull .Type}}{{- end}} `json:"{{ .Col.ColumnName }}" db:"{{ .Col.ColumnName }}"` // {{ .Col.ColumnName }}
	{{- end}}
	{{- end }}
{{- end }}
}

type {{ .Name }}Update struct {
{{- range .Fields }}
{{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInUpdate }}
    {{- if and (or (ne .Col.ColumnName $primaryKey.Col.ColumnName) $tableVar.ManualPk) (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") }}
	{{ .Name }} *{{ retype .Type }} // {{ .Col.ColumnName }}
	{{- end }}
{{- end }}
{{- end }}
}

func (u *{{ .Name }}Update) To{{ .Name }}Create() (res {{ .Name }}Create, err error) {
    {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
        if (u.{{ .Name }} != nil) {
            res.{{ .Name }} = {{- if or .Col.NotNull (ne .Col.IsEnum true) }}*{{ end }}u.{{ .Name }}
        } {{ if .Col.NotNull }} else {
            return res, errors.New("{{ .Col.ColumnName }} is required")
        } {{ end }}
        {{- end }}
    {{- end }}
    return
}

type List{{ .Name }} struct {
    TotalCount int
    Data []{{ .Name }}
}

func (l *List{{ .Name }}) GetInterfaceItems() []interface{} {
    var arr []interface{}
	for _, item := range l.Data {
		arr = append(arr, item)
	}
	return arr
}

