{{- $shortRepo := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $name := .Name }}
{{- $typeName := .TypeName }}

type I{{ .Name }} interface {
{{- range .ManyToOneKeys }}
{{- if ne .CallFuncName "" }}
    {{ .FuncName }}(ctx context.Context, obj *entities.{{ .Type.Name }}, filter *entities.{{ .RefType.Name }}Filter) ({{- if ne .Field.Col.NotNull true}}*{{- end }}entities.{{ .RefType.Name }}, error)
{{- end }}
{{- end }}

{{- range .OneToManyKeys }}
{{- if ne .RevertCallFuncName "" }}
{{- if .IsUnique }}
    {{ .RevertFuncName }}(ctx context.Context, obj *entities.{{ .RefType.Name }}, filter *entities.{{ .Type.Name }}Filter) (*entities.{{ .Type.Name }}, error)
{{- else }}
    {{ .RevertFuncName }}(ctx context.Context, obj *entities.{{ .RefType.Name }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Type.Name }}, error)
{{- end }}
{{- end }}
{{- end }}
}

type {{ .Name }} struct {
    {{- range $k, $v := .DependOnRepo }}
    {{ $v }} I{{ $v }}
    {{- end }}

    {{- range .ManyToOneKeys }}
    {{- if ne .CallFuncName "" }}
        {{ lowerfirst .FuncName }}Loader *util.Loader
    {{- end }}
    {{- end }}
}

var New{{ .Name }} = wire.NewSet(Init{{ .Name }}, wire.Bind(new(I{{ .Name }}), new({{ .Name }})))

func Init{{ .Name }}({{- range $k, $v := .DependOnRepo }}{{ $v }} I{{ $v }}, {{- end }}) *{{ .Name }} {
    return &{{ .Name }}{
        {{- range $k, $v := .DependOnRepo }}{{ $v }}: {{ $v }},{{- end }}

        {{- range .ManyToOneKeys }}
        {{- if ne .CallFuncName "" }}
            {{ lowerfirst .FuncName }}Loader: util.NewLoader(
                func(ctx context.Context, filter util.Filter) (list []interface{}, e error) {
                    result, err := {{ .RefType.RepoName }}.FindAll{{ .RefType.Name }}(ctx, filter.(*entities.{{ .RefType.Name }}Filter), nil)
                    return result.GetInterfaceItems(), err
                },
                func(key interface{}, item interface{}) bool {
                    return util.Compare(item.(entities.{{ .RefType.Name }}).{{ .RefField.Name }}, key)
                },
                func(keys []interface{}, filter util.Filter) {
                    filter.(*entities.{{ .RefType.Name }}Filter).Add{{ .RefField.Name }}(entities.Eq, keys)
                },
            ),
        {{- end }}
        {{- end }}
    }
}

{{- range .ManyToOneKeys }}
{{- if ne .CallFuncName "" }}
func ({{ $shortRepo }} *{{ $name }}) {{ .FuncName }}(ctx context.Context, obj *entities.{{ .Type.Name }}, filter *entities.{{ .RefType.Name }}Filter) (result {{if ne .Field.Col.NotNull true}}*{{- end }}entities.{{ .RefType.Name }}, err error) {
    if obj == nil {
        return result, nil
    }
    var f func() (interface{}, error)
    if f, err = {{ $shortRepo }}.{{ lowerfirst .FuncName }}Loader.Load(obj.{{ .Field.Name }}, filter); err != nil {
        return result, err
    }

    if data, err := f(); err == nil {
        tmp := data.(entities.{{ .RefType.Name }})
        return {{ if ne .Field.Col.NotNull true}}&{{- end }}tmp, nil
    } else {
        {{- if ne .Field.Col.NotNull true }}
            if err == sql.ErrNoRows {
                return nil, nil
            }
            return nil, err
        {{- else }}
            return result, err
        {{- end }}
    }
}
{{- end }}
{{ end }}

{{- range .OneToManyKeys }}
{{- if ne .RevertCallFuncName "" }}
{{- if .IsUnique }}
func ({{ $shortRepo }} *{{ $name }}) {{ .RevertFuncName }}(ctx context.Context, obj *entities.{{ .RefType.Name }}, filter *entities.{{ .Type.Name }}Filter) (*entities.{{ .Type.Name }}, error) {
    if obj ==  nil {
        return nil, nil
    }
    {{- if eq .Field.Type .RefField.Type }}
    res, err := {{ $shortRepo }}.{{ .Type.RepoName}}.{{ .RevertCallFuncName }}(ctx, obj.{{ .RefField.Name }}, filter)
    return &res, err
    {{- else }}
    res, err := {{ $shortRepo }}.{{ .Type.RepoName}}.{{ .RevertCallFuncName }}(ctx, {{convertToNull (print "obj." .RefField.Name) .RefField.Type}}, filter)
    return &res, err
    {{- end }}
}
{{- else }}
func ({{ $shortRepo }} *{{ $name }}) {{ .RevertFuncName }}(ctx context.Context, obj *entities.{{ .RefType.Name }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Type.Name }}, error) {
    if obj ==  nil {
        return entities.List{{ .Type.Name }}{}, nil
    }
    {{- if eq .Field.Type .RefField.Type }}
    return {{ $shortRepo }}.{{ .Type.RepoName}}.{{ .RevertCallFuncName }}(ctx, obj.{{ .RefField.Name }}, filter, pagination)
    {{- else }}
    return {{ $shortRepo }}.{{ .Type.RepoName}}.{{ .RevertCallFuncName }}(ctx, {{convertToNull (print "obj." .RefField.Name) .RefField.Type}}, filter, pagination)
    {{- end }}
}
{{- end }}
{{- end }}
{{ end }}