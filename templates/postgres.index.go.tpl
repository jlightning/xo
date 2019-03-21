{{- $short := (shortname .Type.Name "err" "sqlstr" "db" "q" "res" "XOLog" .Fields) -}}
{{- $shortRepo := (shortname .Type.RepoName "err" "sqlstr" "db" "q" "res" "XOLog" .Fields) -}}
{{- $table := (schema .Type.Table.TableName) -}}
// {{ .FuncName }} retrieves a row from '{{ $table }}' as a {{ .Type.Name }}.
//
// Generated from index '{{ .Index.IndexName }}'.
{{- if .Index.IsUnique }}
func ({{$shortRepo}} *{{ .Type.RepoName }}) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter) (entities.{{ .Type.Name }}, error) {
	var err error

	var db = {{ $shortRepo }}.Db
    tx := db_manager.GetTransactionContext(ctx)
    if tx != nil {
        db = tx
    }

	// sql query
    qb, err := {{$shortRepo}}.FindAll{{ .Type.Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*")
    if err != nil {
        return entities.{{ .Type.Name }}{}, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
    {{- range $k, $v := .Fields }}
        qb = qb.Where(sq.Eq{"`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}

    {{- if .Type.HasActiveField }}
    qb = qb.Where(sq.Eq{"`active`": true})
    {{- end }}

	// run query
	{{ $short }} := entities.{{ .Type.Name }}{}
	err = db.Get(ctx, &{{ $short }}, qb)
    if err != nil {
        return entities.{{ .Type.Name }}{}, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
	return {{ $short }}, nil
}
{{- else }}
func ({{$shortRepo}} *{{ .Type.RepoName }}) {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (list entities.List{{ .Type.Name }}, err error) {
	var db = {{ $shortRepo }}.Db
    tx := db_manager.GetTransactionContext(ctx)
    if tx != nil {
        db = tx
    }

	// sql query
	qb, err := {{$shortRepo}}.FindAll{{ .Type.Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*")
	if err != nil {
        return list, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }
	{{- range $k, $v := .Fields }}
	    qb = qb.Where(sq.Eq{"`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}
	if qb, err = {{$shortRepo}}.AddPagination(ctx, qb, pagination); err != nil {
	    return list, err
	}

	// run query
    if err = db.Select(ctx, &list.Data, qb); err != nil {
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
        qb = qb.Where(sq.Eq{"`{{ colname .Col }}`": {{ goparam $v }}})
    {{- end }}
    if err = db.Get(ctx, &listMeta, qb); err != nil {
        return list, errors.Wrap(err, "error in {{ .Type.RepoName }}")
    }

    list.TotalCount = listMeta.Count

    return list, nil
}
{{- end }}

