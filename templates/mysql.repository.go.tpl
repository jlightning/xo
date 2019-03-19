{{- $shortRepo := (shortname .RepoName "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $table := (schema .Table.TableName) -}}
{{- $primaryKey := .PrimaryKey }}
{{- $type := . }}
{{- if .Comment -}}
// {{ .Comment }}
{{- else -}}

type I{{ .RepoName }} interface {
    {{ if .PrimaryKey }}
    Insert{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}Create) (*entities.{{ .Name }}, error)
    Insert{{ .Name }}WithSuffix(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (*entities.{{ .Name }}, error)
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
    Update{{ .Name }}ByFields(ctx context.Context, {{- range .PrimaryKeyFields }}{{ .Name }} {{ retype .Type }}{{- end }}, {{ $short }} entities.{{ .Name }}Update) (*entities.{{ .Name }}, error)
    Update{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) (*entities.{{ .Name }}, error)
    {{- end }}
    Delete{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) error
    FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string) (*sq.SelectBuilder, error)
    AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error)
    FindAll{{ .Name }}(ctx context.Context, {{$short}}Filter *entities.{{ .Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Name }}, error)
    {{- range .Indexes }}
        {{- if .Index.IsUnique }}
        {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter) (entities.{{ .Type.Name }}, error)
        {{- else }}
        {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Type.Name }}, error)
        {{- end  }}
        {{- end }}
    {{- end }}
}

{{ if .DoesTableGenApprovalTable }}
type I{{ .Name }}CRRepository interface {
    Approve{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark *string) (bool, error)
    Reject{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error)
    Cancel{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error)
    Submit{{ .Name }}Draft(ctx context.Context, IDDraft int, remark *string) (bool, error)
}
{{- end }}

// {{ lowerfirst .RepoName }} represents a row from '{{ $table }}'.
{{- end }}
type {{ .RepoName }} struct {
    Db db_manager.IDb
    {{- if .DoesTableGenApprovalTable }}
    {{ .Name }}DraftRepository I{{ .Name }}DraftRepository
    {{ .Name }}DraftActivityLogRepository I{{ .Name }}DraftActivityLogRepository
    {{ .Name }}DraftItemRepository I{{ .Name }}DraftItemRepository
    {{- end }}
}

var  New{{ .RepoName }} = wire.NewSet({{ .RepoName }}{}, wire.Bind(new(I{{ .RepoName }}), new({{ .RepoName }})), {{- if .DoesTableGenApprovalTable -}} wire.Bind(new(I{{ .Name }}CRRepository), new({{ .RepoName }})) {{- end }})

{{ if .PrimaryKey }}

// Insert inserts the {{ .Name }}Create to the database.
func ({{ $shortRepo }} *{{ .RepoName }}) Insert{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}Create) (*entities.{{ .Name }}, error) {
    return {{ $shortRepo }}.Insert{{ .Name }}WithSuffix(ctx, {{ $short }}, nil)
}

func ({{ $shortRepo }} *{{ .RepoName }}) Insert{{ .Name }}WithSuffix(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (*entities.{{ .Name }}, error) {
	var err error

	var db = {{ $shortRepo }}.Db
    tx := db_manager.GetTransactionContext(ctx)
    if tx != nil {
        db = tx
    }

{{ if .Table.ManualPk  }}
	// sql insert query, primary key must be provided
	qb := sq.Insert("`{{ $table }}`").Columns(
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
            "`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
    ).Values(
         {{- range .Fields }}
         {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) }}
             {{ $short }}.{{ .Name }},
         {{- end }}
         {{- end }}
    )
    if suffix != nil {
        suffixQuery, suffixArgs, suffixErr := suffix.ToSql()
        if suffixErr != nil {
            return nil, suffixErr
        }
        qb.Suffix(suffixQuery, suffixArgs...)
    }
    query, args, err := qb.ToSql()
	if err != nil {
	    return nil, errors.Wrap(err, "error in {{ .RepoName }}")
	}

	// run query
	res, err := db.Exec(query, args...)
	if err != nil {
		return nil, errors.Wrap(err, "error in {{ .RepoName }}")
	}

{{ else }}
	// sql insert query, primary key provided by autoincrement
	qb := sq.Insert("`{{ $table }}`").Columns(
	    {{- range .Fields }}
	    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) }}
            "`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
	).Values(
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) }}
            {{ $short }}.{{ .Name }},
        {{- end }}
        {{- end }}
	)
	if suffix != nil {
        suffixQuery, suffixArgs, suffixErr := suffix.ToSql()
        if suffixErr != nil {
            return nil, suffixErr
        }
        qb.Suffix(suffixQuery, suffixArgs...)
    }
	query, args, err := qb.ToSql()
	if err != nil {
	    return nil, errors.Wrap(err, "error in {{ .RepoName }}")
	}

	// run query
	res, err := db.Exec(query, args...)
	if err != nil {
		return nil, errors.Wrap(err, "error in {{ .RepoName }}")
	}
{{ end }}

    // retrieve id
	id, err := res.LastInsertId()
	if err != nil {
		return nil, errors.Wrap(err, "error in {{ .RepoName }}")
	}

	new{{ $short }} := entities.{{ .Name }}{}

	err = db.Get(&new{{ $short }}, "SELECT * FROM `{{ $table }}` WHERE `{{ .PrimaryKey.Col.ColumnName }}` = ?", id)

	return &new{{ $short }}, errors.Wrap(err, "error in {{ .RepoName }}")
}

{{ if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
	// Update updates the {{ .Name }}Create in the database.
	func ({{ $shortRepo }} *{{ .RepoName }}) Update{{ .Name }}ByFields(ctx context.Context, {{- range .PrimaryKeyFields }}{{ .Name }} {{ retype .Type }}{{- end }}, {{ $short }} entities.{{ .Name }}Update) (*entities.{{ .Name }}, error) {
		var err error

		var db = {{ $shortRepo }}.Db
        tx := db_manager.GetTransactionContext(ctx)
        if tx != nil {
            db = tx
        }

        updateMap := map[string]interface{}{}
        {{- range .Fields }}
            {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) }}
            if ({{ $short }}.{{ .Name }} != nil) {
                updateMap["`{{ .Col.ColumnName }}`"] = *{{ $short }}.{{ .Name }}
            }
            {{- end }}
        {{- end }}

		{{ if gt ( len .PrimaryKeyFields ) 1 }}
			// sql query with composite primary key
			qb := sq.Update("`{{ $table }}`").SetMap(updateMap).Where(sq.Eq{
            {{- range .PrimaryKeyFields }}
                "`{{ .Col.ColumnName }}`": .{{ .Name }},
            {{- end }}
            })
		{{- else }}
			// sql query
			qb := sq.Update("`{{ $table }}`").SetMap(updateMap).Where(sq.Eq{"`{{ .PrimaryKey.Col.ColumnName }}`": {{ .PrimaryKey.Name }}})
		{{- end }}
		query, args, err := qb.ToSql()
        if err != nil {
            return nil, errors.Wrap(err, "error in {{ .RepoName }}")
        }

        // run query
        _, err = db.Exec(query, args...)
        if err != nil {
            return nil, errors.Wrap(err, "error in {{ .RepoName }}")
        }

        selectQb := sq.Select("*").From("`{{ $table }}`")
        {{- if gt ( len .PrimaryKeyFields ) 1 }}
            selectQb = selectQb.Where(sq.Eq{
                {{- range .PrimaryKeyFields }}
                    "`{{ .Col.ColumnName }}`": .{{ .Name }},
                {{- end }}
                })
        {{- else }}
            selectQb = selectQb.Where(sq.Eq{"`{{ .PrimaryKey.Col.ColumnName }}`": {{ .PrimaryKey.Name }}})
        {{- end }}

        query, args, err = selectQb.ToSql()
        if err != nil {
            return nil, errors.Wrap(err, "error in {{ .RepoName }}")
        }

        result := entities.{{ .Name }}{}
        err = db.Get(&result, query, args...)
        return &result, errors.Wrap(err, "error in {{ .RepoName }}")
	}

    // Update updates the {{ .Name }} in the database.
	func ({{ $shortRepo }} *{{ .RepoName }}) Update{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) (*entities.{{ .Name }}, error) {
    		var err error

    		var db = {{ $shortRepo }}.Db
            tx := db_manager.GetTransactionContext(ctx)
            if tx != nil {
                db = tx
            }

    		{{ if gt ( len .PrimaryKeyFields ) 1 }}
    			// sql query with composite primary key
    			qb := sq.Update("`{{ $table }}`").SetMap(map[string]interface{}{
                {{- range .Fields }}
                    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
                    "`{{ .Col.ColumnName }}`": {{ $short }}.{{ .Name }},
                    {{- end }}
                {{- end }}
                }).Where(sq.Eq{
                {{- range .PrimaryKeyFields }}
                    "`{{ .Col.ColumnName }}`": {{ $short}}.{{ .Name }},
                {{- end }}
                })
    		{{- else }}
    			// sql query
    			qb := sq.Update("`{{ $table }}`").SetMap(map[string]interface{}{
    			{{- range .Fields }}
    			    {{- if ne .Name $primaryKey.Name }}
    			    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
    			    "`{{ .Col.ColumnName }}`": {{ $short }}.{{ .Name }},
    			    {{- end }}
    			    {{- end }}
                {{- end }}
                }).Where(sq.Eq{"`{{ .PrimaryKey.Col.ColumnName }}`": {{ $short}}.{{ .PrimaryKey.Name }}})
    		{{- end }}
    		query, args, err := qb.ToSql()
            if err != nil {
                return nil, errors.Wrap(err, "error in {{ .RepoName }}")
            }

            // run query
            _, err = db.Exec(query, args...)
            if err != nil {
                return nil, errors.Wrap(err, "error in {{ .RepoName }}")
            }

            selectQb := sq.Select("*").From("`{{ $table }}`")
            {{- if gt ( len .PrimaryKeyFields ) 1 }}
                selectQb = selectQb.Where(sq.Eq{
                    {{- range .PrimaryKeyFields }}
                        "`{{ .Col.ColumnName }}`": {{ $short}}.{{ .Name }},
                    {{- end }}
                    })
            {{- else }}
                selectQb = selectQb.Where(sq.Eq{"`{{ .PrimaryKey.Col.ColumnName }}`": {{ $short}}.{{ .PrimaryKey.Name }}})
            {{- end }}

            query, args, err = selectQb.ToSql()
            if err != nil {
                return nil, errors.Wrap(err, "error in {{ .RepoName }}")
            }

            result := entities.{{ .Name }}{}
            err = db.Get(&result, query, args...)
            return &result, errors.Wrap(err, "error in {{ .RepoName }}")
    	}
{{ else }}
	// Update statements omitted due to lack of fields other than primary key
{{ end }}

// Delete deletes the {{ .Name }} from the database.
func ({{ $shortRepo }} *{{ .RepoName }}) Delete{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) error {
	var err error

	var db = {{ $shortRepo }}.Db
    tx := db_manager.GetTransactionContext(ctx)
    if tx != nil {
        db = tx
    }

    {{ if .HasActiveField }}
    qb := sq.Update("`{{ $table }}`").Set("active", false)
    {{ else }}
    qb := sq.Delete("`{{ $table }}`")
    {{ end -}}

	{{- if gt ( len .PrimaryKeyFields ) 1 -}}
		qb = qb.Where(sq.Eq{
        {{- range .PrimaryKeyFields }}
            "`{{ .Col.ColumnName }}`": {{ $short }}.{{ .Name }},
        {{- end }}
        })
	{{- else -}}
		qb = qb.Where(sq.Eq{"`{{ colname .PrimaryKey.Col}}`": {{ $short }}.{{ .PrimaryKey.Name }}})
	{{- end }}

	query, args, err := qb.ToSql()
    if err != nil {
        return errors.Wrap(err, "error in {{ .RepoName }}")
    }

    // run query
    _, err = db.Exec(query, args...)
    return errors.Wrap(err, "error in {{ .RepoName }}")
}

func ({{ $shortRepo }} *{{ .RepoName }}) FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string) (*sq.SelectBuilder, error) {
    var err error
    qb := sq.Select(fields).From("`{{ $table }}`")
    if filter != nil {
        {{- range .Fields }}
            {{- if ne .Col.IsVirtualFromConfig true }}
            {{- if eq .Col.ColumnName "active" }}
                if filter.Active == nil {
                    if qb, err = addFilter(qb, "`{{ $table }}`.`{{ .Col.ColumnName }}`", entities.FilterOnField{ {entities.Eq: true} }); err != nil {
                        return qb, err
                    }
                } else {
                    if qb, err = addFilter(qb, "`{{ $table }}`.`{{ .Col.ColumnName }}`", filter.{{ .Name }}); err != nil {
                        return qb, err
                    }
                }
            {{- else }}
                if qb, err = addFilter(qb, "`{{ $table }}`.`{{ .Col.ColumnName }}`", filter.{{ .Name }}); err != nil {
                    return qb, err
                }
            {{- end }}
            {{- end }}
        {{- end }}

        if filter.Wheres != nil {
            for _, where := range filter.Wheres {
                query, args, err := where.ToSql()
                if err != nil {
                    return qb, err
                }
                qb = qb.Where(query, args...)
            }
        }
        if filter.Joins != nil {
            for _, join := range filter.Joins {
                query, args, err := join.ToSql()
                if err != nil {
                    return qb, err
                }
                qb = qb.Join(query, args...)
            }
        }
        if filter.LeftJoins != nil {
            for _, leftJoin := range filter.LeftJoins {
                query, args, err := leftJoin.ToSql()
                if err != nil {
                    return qb, err
                }
                qb = qb.LeftJoin(query, args...)
            }
        }
        if filter.GroupBys != nil {
            qb = qb.GroupBy(filter.GroupBys...)
        }
        if filter.OrderBys != nil {
            qb.OrderBy(filter.OrderBys...)
        }
    } else {
        {{- range .Fields }}
            {{- if ne .Col.IsVirtualFromConfig true }}
                {{- if eq .Col.ColumnName "active" }}
                    if qb, err = addFilter(qb, "`{{ $table }}`.`{{ .Col.ColumnName }}`", entities.FilterOnField{ {entities.Eq: true} }); err != nil {
                        return qb, err
                    }
                {{- end }}
            {{- end }}
        {{- end }}
    }

    return qb, nil
}

func ({{ $shortRepo }} *{{ .RepoName }}) AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error) {
    sortFieldMap := map[string]string{
        {{- range .Fields }}
            {{- if ne .Col.IsVirtualFromConfig true }}
                "{{ lowerfirst .Name }}": "`{{ .Col.ColumnName }}` ASC",
                "-{{ lowerfirst .Name }}": "`{{ .Col.ColumnName }}` DESC",
                {{- if ne .Col.ColumnName (lowerfirst .Name) }}
                    "{{ .Col.ColumnName }}": "`{{ .Col.ColumnName }}` ASC",
                    "-{{ .Col.ColumnName }}": "`{{ .Col.ColumnName }}` DESC",
                {{- end }}
            {{- end }}
        {{- end }}
    }
    return addPagination(qb, pagination, sortFieldMap)
}

func ({{ $shortRepo }} *{{ .RepoName }}) FindAll{{ .Name }}(ctx context.Context, filter *entities.{{ .Name }}Filter, pagination *entities.Pagination) (list entities.List{{ .Name }}, err error) {
    var db = {{ $shortRepo }}.Db
    tx := db_manager.GetTransactionContext(ctx)
    if tx != nil {
        db = tx
    }

    qb, err := {{ $shortRepo }}.FindAll{{ .Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*")
    if err != nil {
        return entities.List{{ .Name }}{}, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    qb, err = {{ $shortRepo }}.AddPagination(ctx, qb, pagination)
    if err != nil {
        return entities.List{{ .Name }}{}, errors.Wrap(err, "error in {{ .RepoName }}")
    }

    query, args, err := qb.ToSql()
    if err != nil {
        return list, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    err = db.Select(&list.Data, query, args...)

    if err != nil {
        return list, errors.Wrap(err, "error in {{ .RepoName }}")
    }

    if pagination == nil || pagination.PerPage == nil || pagination.Page == nil {
        list.TotalCount = len(list.Data)
        return list, nil
    }

    var listMeta entities.ListMetadata
    if qb, err = {{ $shortRepo }}.FindAll{{ .Name }}BaseQuery(ctx, filter, "COUNT(1) AS count"); err != nil {
        return entities.List{{ .Name }}{}, err
    }
    if filter != nil && len(filter.GroupBys) > 0 {
        qb = sq.Select("COUNT(1) AS count").FromSelect(qb, "a")
    }
    query, args, err = qb.ToSql()
    if err != nil {
        return list, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    err = db.Get(&listMeta, query, args...)

    list.TotalCount = listMeta.Count

    return list, errors.Wrap(err, "error in {{ .RepoName }}")
}
{{- end }}

{{ if .DoesTableGenApprovalTable }}
func ({{ $shortRepo }} *{{ .RepoName }}) Approve{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark *string) (bool, error) {
    user := consts.GetUserContext(ctx)
    if user == nil {
        return false, consts.ErrUnauthorized
    }

    ctx, newTxCreated, tx, err := db_manager.StartTransaction(ctx, {{ $shortRepo }}.Db.(db_manager.IDbTxBeginner))
    if err != nil {
        return false, err
    }

    if newTxCreated {
        defer db_manager.CommitTx(tx, &err, nil, nil)
    }

    // TODO: lock row
    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByID(ctx, IDDraft, nil)
    if err != nil {
        return false, err
    }
    if draft.Status != entities.{{ .Name }}DraftStatusPending {
        return false, errors.New("invalid draft status")
    }

    newStatus := entities.{{ .Name }}DraftStatusApproved
    fkApprover := util.NewNullInt64(int64(user.ID))
    if _, err = {{ $shortRepo }}.{{ .Name }}DraftRepository.Update{{ .Name }}DraftByFields(ctx, IDDraft, entities.{{ .Name }}DraftUpdate{Status: &newStatus, FkApprover: &fkApprover}); err != nil {
        return false, err
    }

    var remarkNullStr sql.NullString
    if remark != nil {
        remarkNullStr = sql.NullString{Valid: true, String: *remark}
    }

    if _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkApprover,
        Status: entities.{{ .Name }}DraftActivityLogStatusApproved,
        Remark: remarkNullStr,
        Active: true,
    }); err != nil {
        return false, err
    }

    draftItems, err := {{ $shortRepo }}.{{ .Name }}DraftItemRepository.FindAll{{ .Name }}DraftItem(ctx, &entities.{{ .Name }}DraftItemFilter{
        FkDraft: entities.FilterOnField{{`{{ entities.Eq: IDDraft }}`}},
        {{- if .IsIncludeInactiveOnMove }}
        Active: entities.FilterOnField{{`{{ entities.Eq: []interface{}{false, true} }}`}},
        {{- end }}
    }, nil)
    if err != nil {
        return false, err
    }

    for _, draftItem := range draftItems.Data {
        item := entities.{{ .Name }}Create{
            {{- range .Fields }}
                {{- if ne .Name $primaryKey.Name }}
                    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
                        {{- if ne .Col.IsVirtualFromConfig true }}
                            {{- if ne .Col.IsEnum true }}
                                {{ .Name }}: draftItem.{{ .Name }},
                            {{- end }}
                        {{- end }}
                    {{- end }}
                {{- end }}
            {{- end }}
        }
        {{- range .Fields }}
            {{- if ne .Name $primaryKey.Name }}
                {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
                    {{- if ne .Col.IsVirtualFromConfig true }}
                        {{- if .Col.IsEnum }}
                            if byteData, err := draftItem.{{ .Name }}.MarshalText(); err != nil {
                                return false, err
                            } else {
                                var tmp{{ .Name }} entities.{{ $type.Name }}{{ .Name }}
                                if err = tmp{{ .Name }}.UnmarshalText(byteData); err != nil {
                                     return false, err
                                }
                                item.{{ .Name }} = {{- if ne .Col.NotNull true -}}&{{- end -}}tmp{{ .Name }}
                            }
                        {{- end }}
                    {{- end }}
                {{- end }}
            {{- end }}
        {{- end }}

        onDuplicate := (sq.Sqlizer)(nil)
        {{- if .IsApprovalTableOnDuplicateUpdate }}
            onDuplicate = sq.Expr("{{ `ON DUPLICATE KEY UPDATE ` }}
                {{- range .Fields }}
                    {{- if ne .Name $primaryKey.Name }}
                        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
                            {{- if ne .Col.IsVirtualFromConfig true -}}
                                `{{ $type.Table.TableName }}`.`{{ .Col.ColumnName }}` = ?,
                            {{- end -}}
                        {{- end }}
                    {{- end }}
                {{- end -}}
                `{{ $type.Table.TableName }}`.`updated_at` = NOW()",
                {{- range .Fields }}
                    {{- if ne .Name $primaryKey.Name }}
                        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) }}
                            {{- if ne .Col.IsVirtualFromConfig true -}}
                                draftItem.{{ .Name }},
                            {{- end -}}
                        {{- end }}
                    {{- end }}
                {{- end }}
            )
        {{- end }}

        if _, err = {{ $shortRepo }}.Insert{{ .Name }}WithSuffix(ctx, item, onDuplicate); err != nil {
            return false, err
        }
    }
    return true, nil
}

func ({{ $shortRepo }} *{{ .RepoName }}) Reject{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error) {
    user := consts.GetUserContext(ctx)
    if user == nil {
        return false, consts.ErrUnauthorized
    }
    fkApprover := util.NewNullInt64(int64(user.ID))

    // TODO: lock row
    ctx, newTxCreated, tx, err := db_manager.StartTransaction(ctx, {{ $shortRepo }}.Db.(db_manager.IDbTxBeginner))
    if err != nil {
        return false, err
    }

    if newTxCreated {
        defer db_manager.CommitTx(tx, &err, nil, nil)
    }

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByID(ctx, IDDraft, nil)
    if err != nil {
        return false, err
    }
    if draft.Status != entities.{{ .Name }}DraftStatusPending {
        err = errors.New("invalid draft status")
        return false, err
    }
    newStatus := entities.{{ .Name }}DraftStatusRejected
    if _, err = {{ $shortRepo }}.{{ .Name }}DraftRepository.Update{{ .Name }}DraftByFields(ctx, IDDraft, entities.{{ .Name }}DraftUpdate{Status: &newStatus, FkApprover: &fkApprover}); err != nil {
        return false, err
    }

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkApprover,
        Status: entities.{{ .Name }}DraftActivityLogStatusRejected,
        Remark: sql.NullString{Valid: true, String: remark},
        Active: true,
    })
    return err == nil, err
}

func ({{ $shortRepo }} *{{ .RepoName }}) Cancel{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error) {
    user := consts.GetUserContext(ctx)
    if user == nil {
        return false, consts.ErrUnauthorized
    }
    fkUser := util.NewNullInt64(int64(user.ID))

    // TODO: lock row
    ctx, newTxCreated, tx, err := db_manager.StartTransaction(ctx, {{ $shortRepo }}.Db.(db_manager.IDbTxBeginner))
    if err != nil {
        return false, err
    }

    if newTxCreated {
        defer db_manager.CommitTx(tx, &err, nil, nil)
    }

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByID(ctx, IDDraft, nil)
    if err != nil {
        return false, err
    }
    if draft.Status != entities.{{ .Name }}DraftStatusPending && draft.Status != entities.{{ .Name }}DraftStatusDraft {
        err = errors.New("invalid draft status")
        return false, err
    }
    newStatus := entities.{{ .Name }}DraftStatusCancelled
    if _, err = {{ $shortRepo }}.{{ .Name }}DraftRepository.Update{{ .Name }}DraftByFields(ctx, IDDraft, entities.{{ .Name }}DraftUpdate{Status: &newStatus}); err != nil {
        return false, err
    }

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkUser,
        Status: entities.{{ .Name }}DraftActivityLogStatusCancelled,
        Remark: sql.NullString{Valid: true, String: remark},
        Active: true,
    })
    return err == nil, err
}

func ({{ $shortRepo }} *{{ .RepoName }}) Submit{{ .Name }}Draft(ctx context.Context, IDDraft int, remark *string) (bool, error) {
    user := consts.GetUserContext(ctx)
    if user == nil {
        return false, consts.ErrUnauthorized
    }
    fkUser := util.NewNullInt64(int64(user.ID))

    // TODO: lock row
    ctx, newTxCreated, tx, err := db_manager.StartTransaction(ctx, {{ $shortRepo }}.Db.(db_manager.IDbTxBeginner))
    if err != nil {
        return false, err
    }

    if newTxCreated {
        defer db_manager.CommitTx(tx, &err, nil, nil)
    }

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByID(ctx, IDDraft, nil)
    if err != nil {
        return false, err
    }
    if draft.Status != entities.{{ .Name }}DraftStatusDraft {
        err = errors.New("invalid draft status")
        return false, err
    }
    newStatus := entities.{{ .Name }}DraftStatusPending
    var remarkNullStr sql.NullString
    if remark != nil {
        remarkNullStr = sql.NullString{Valid: true, String: *remark}
    }
    if _, err = {{ $shortRepo }}.{{ .Name }}DraftRepository.Update{{ .Name }}DraftByFields(ctx, IDDraft, entities.{{ .Name }}DraftUpdate{Status: &newStatus}); err != nil {
        return false, err
    }

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkUser,
        Status: entities.{{ .Name }}DraftActivityLogStatusPending,
        Remark: remarkNullStr,
        Active: true,
    })
    return err == nil, err
}

{{ end }}
