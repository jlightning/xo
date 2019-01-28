{{- $shortRepo := (shortname .RepoName "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $table := (schema .Table.TableName) -}}
{{- $primaryKey := .PrimaryKey }}
{{- $repoName := .RepoName }}

type {{ .RepoName }}Mock struct {
    mock.Mock
    realRepo *repositories.{{ .RepoName }}
    mockedMethods map[string]bool
}

var New{{ .RepoName }}Mock = wire.NewSet(Init{{ .RepoName }}Mock, wire.Bind(new(repositories.I{{ .RepoName }}), new({{ .RepoName }}Mock)))

func Init{{ .RepoName }}Mock(realRepo *repositories.{{ .RepoName }}) *{{ .RepoName }}Mock {
    return &{{ .RepoName }}Mock{
        Mock: mock.Mock{},
        realRepo: realRepo,
        mockedMethods: map[string]bool{},
    }
}

func (repo *{{ .RepoName }}Mock) On(methodName string, arguments ...interface{}) *mock.Call {
    repo.mockedMethods[methodName] = true
    return repo.Mock.On(methodName, arguments...)
}

func (repo *{{ .RepoName }}Mock) Insert{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}Create) (*entities.{{ .Name }}, error) {
    if !repo.mockedMethods["Insert{{ .Name }}"] {
        return repo.realRepo.Insert{{ .Name }}(ctx, {{ $short }})
    }
    args := repo.Called(ctx, {{ $short }})
    return args.Get(0).(*entities.{{ .Name }}), args.Error(1)
}

{{ if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
func (repo *{{ .RepoName }}Mock) Update{{ .Name }}ByFields(ctx context.Context, {{- range .PrimaryKeyFields }}{{ .Name }} {{ retype .Type }}{{- end }}, {{ $short }} entities.{{ .Name }}Update) (*entities.{{ .Name }}, error) {
    if !repo.mockedMethods["Update{{ .Name }}ByFields"] {
        return repo.realRepo.Update{{ .Name }}ByFields(ctx, {{- range .PrimaryKeyFields }}{{ .Name }}{{- end }}, {{ $short }})
    }
    args := repo.Called(ctx, {{- range .PrimaryKeyFields }}{{ .Name }}{{- end }}, {{ $short }})
    return args.Get(0).(*entities.{{ .Name }}), args.Error(1)
}

func (repo *{{ .RepoName }}Mock) Update{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) (*entities.{{ .Name }}, error) {
    if !repo.mockedMethods["Update{{ .Name }}"] {
        return repo.realRepo.Update{{ .Name }}(ctx, {{ $short }})
    }
    args := repo.Called(ctx, {{ $short }})
    return args.Get(0).(*entities.{{ .Name }}), args.Error(1)
}
{{ end }}

func (repo *{{ .RepoName }}Mock) Delete{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) error {
    if !repo.mockedMethods["Delete{{ .Name }}"] {
        return repo.realRepo.Delete{{ .Name }}(ctx, {{ $short }})
    }
    args := repo.Called(ctx, {{ $short }})
    return args.Error(0)
}

func (repo *{{ .RepoName }}Mock) FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string) *sq.SelectBuilder {
    if !repo.mockedMethods["FindAll{{ .Name }}BaseQuery"] {
        return repo.realRepo.FindAll{{ .Name }}BaseQuery(ctx, filter, fields)
    }
    args := repo.Called(ctx, filter, fields)
    return args.Get(0).(*sq.SelectBuilder)
}

func (repo *{{ .RepoName }}Mock) AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error) {
    if !repo.mockedMethods["AddPagination"] {
        return repo.realRepo.AddPagination(ctx, qb, pagination)
    }
    args := repo.Called(ctx, qb, pagination)
    return args.Get(0).(*sq.SelectBuilder), args.Error(1)
}

func (repo *{{ .RepoName }}Mock) FindAll{{ .Name }}(ctx context.Context, filter *entities.{{ .Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Name }}, error) {
    if !repo.mockedMethods["FindAll{{ .Name }}"] {
        return repo.realRepo.FindAll{{ .Name }}(ctx, filter, pagination)
    }
    args := repo.Called(ctx, filter, pagination)
    return args.Get(0).(entities.List{{ .Name }}), args.Error(1)
}
{{- range .Indexes }}

    {{ if .Index.IsUnique }}
    func (repo *{{ $repoName }}Mock) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter) (entities.{{ .Type.Name }}, error) {
        if !repo.mockedMethods["{{ .FuncName }}"] {
            return repo.realRepo.{{ .FuncName }}(ctx, {{ goparamlist .Fields false false }}, filter)
        }
        args := repo.Called(ctx, {{ goparamlist .Fields false false }}, filter)
        return args.Get(0).(entities.{{ .Type.Name }}), args.Error(1)
    }
    {{- else }}
    func (repo *{{ $repoName }}Mock) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Type.Name }}, error) {
        if !repo.mockedMethods["{{ .FuncName }}"] {
            return repo.realRepo.{{ .FuncName }}(ctx, {{ goparamlist .Fields false false }}, filter, pagination)
        }
        args := repo.Called(ctx, {{ goparamlist .Fields false false }}, filter, pagination)
        return args.Get(0).(entities.List{{ .Type.Name }}), args.Error(1)
    }
    {{- end }}
{{ end }}