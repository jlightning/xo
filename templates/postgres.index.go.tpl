{{- $short := (shortname .Type.Name "err" "sqlstr" "db" "q" "res" "XOLog" .Fields) -}}
{{- $shortRepo := (shortname .Type.RepoName "err" "sqlstr" "db" "q" "res" "XOLog" .Fields) -}}
{{- $table := (schema .Type.Table.TableName) -}}
// {{ .FuncName }} retrieves a row from '{{ $table }}' as a {{ .Type.Name }}.
//
// Generated from index '{{ .Index.IndexName }}'.
{{- if .Index.IsUnique }}
func ({{$shortRepo}} *{{ .Type.RepoName }}) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter) (entities.{{ .Type.Name }}, error) {
	var err error

	// sql query
    qb, err := {{$shortRepo}}.FindAll{{ .Type.Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*")
    if err != nil {
        return entities.{{ .Type.Name }}{}, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
    {{- range $k, $v := .Fields }}
        qb = qb.Where(sq.Eq{"`{{ $table }}`.`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}

	// run query
	{{ $short }} := entities.{{ .Type.Name }}{}
	err = {{ $shortRepo }}.Db.Get(ctx, &{{ $short }}, qb)
    if err != nil {
        return entities.{{ .Type.Name }}{}, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
	return {{ $short }}, nil
}
{{- else }}
func ({{$shortRepo}} *{{ .Type.RepoName }}) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (list entities.List{{ .Type.Name }}, err error) {
	// sql query
	qb, err := {{$shortRepo}}.FindAll{{ .Type.Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*")
	if err != nil {
        return list, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
	{{- range $k, $v := .Fields }}
	    qb = qb.Where(sq.Eq{"`{{ $table }}`.`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}
	if qb, err = {{$shortRepo}}.AddPagination(ctx, qb, pagination); err != nil {
	    return list, err
	}

	// run query
    if err = {{ $shortRepo }}.Db.Select(ctx, &list.Data, qb); err != nil {
        return list, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }

    if pagination == nil || pagination.PerPage == nil || pagination.Page == nil {
        list.TotalCount = len(list.Data)
        return list, nil
    }

    var listMeta entities.ListMetadata
    if qb, err = {{ $shortRepo }}.FindAll{{ .Type.Name }}BaseQuery(ctx, filter, "COUNT(1) AS count"); err != nil {
        return list, err
    }
    if filter != nil && len(filter.GroupBys) > 0 {
        qb = sq.Select("COUNT(1) AS count").FromSelect(qb, "a")
    }
    {{- range $k, $v := .Fields }}
        qb = qb.Where(sq.Eq{"`{{ $table }}`.`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}
    if err = {{ $shortRepo }}.Db.Get(ctx, &listMeta, qb); err != nil {
        return list, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }

    list.TotalCount = listMeta.Count

    return list, nil
}
{{- end }}

