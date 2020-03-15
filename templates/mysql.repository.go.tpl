{{- $shortRepo := (shortname .RepoName "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $name := .Name }}
{{- $table := (schema .Table.TableName) -}}
{{- $primaryKey := .PrimaryKey }}
{{- $type := . }}
{{- if .Comment -}}
// {{ .Comment }}
{{- else -}}

// I{{ .RepoName }} contains all the methods for CRUD of '{{ $table }}'
type I{{ .RepoName }} interface {
    I{{ .RepoName }}QueryBuilder
    {{ if .PrimaryKey }}
    Insert{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}Create) (*entities.{{ .Name }}, error)
    Insert{{ .Name }}WithSuffix(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (*entities.{{ .Name }}, error)
    Insert{{ .Name }}IDResult(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (int64, error)
    {{- if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
    Update{{ .Name }}ByFields(ctx context.Context, {{- range .PrimaryKeyFields }}{{ .Name }} {{ retype .Type }}{{- end }}, {{ $short }} entities.{{ .Name }}Update) (*entities.{{ .Name }}, error)
    Update{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) (*entities.{{ .Name }}, error)
    {{- end }}
    Delete{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) error
    {{- if eq ( len .PrimaryKeyFields ) 1 }}
    Delete{{ .Name }}By{{ $primaryKey.Name }}(ctx context.Context, id {{ $primaryKey.Type }}) (bool, error)
    {{- end }}
    FindAll{{ .Name }}(ctx context.Context, {{$short}}Filter *entities.{{ .Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Name }}, error)
    FindAll{{ .Name }}WithSuffix(ctx context.Context, {{$short}}Filter *entities.{{ .Name }}Filter, pagination *entities.Pagination, suffixes ...sq.Sqlizer) (entities.List{{ .Name }}, error)
    {{- range .Indexes }}
        {{- if .Index.IsUnique }}
        {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter) (entities.{{ .Type.Name }}, error)
        {{ .FuncName }}WithSuffix(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, suffixes ...sq.Sqlizer) (entities.{{ .Type.Name }}, error)
        {{- else }}
        {{ .FuncName }}(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination) (entities.List{{ .Type.Name }}, error)
        {{ .FuncName }}WithSuffix(ctx context.Context, {{ goparamlist .Fields false true }}, filter *entities.{{ .Type.Name }}Filter, pagination *entities.Pagination, suffixes ...sq.Sqlizer) (entities.List{{ .Type.Name }}, error)
        {{- end  }}
        {{- end }}
    {{- end }}
    {{ if .DoesTableGenAuditLogsTable }}
    InsertAuditLog(ctx context.Context, id int, action AuditLogAction) error
    {{ end }}
}

// I{{ .RepoName }}QueryBuilder contains all the methods for query builder of '{{ $table }}'
type I{{ .RepoName }}QueryBuilder interface {
    FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string, suffixes ...sq.Sqlizer) (*sq.SelectBuilder, error)
    AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error)
}

{{ if .DoesTableGenApprovalTable }}
// I{{ .RepoName }}QueryBuilder contains all the methods for approval flow of '{{ $table }}'
type I{{ .Name }}CRRepository interface {
    Approve{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark *string) (bool, error)
    Reject{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error)
    Cancel{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error)
    Submit{{ .Name }}Draft(ctx context.Context, IDDraft int, remark *string) (bool, error)
}
{{- end }}

{{- end }}
// {{ .RepoName }} is responsible for CRUD from / to '{{ $table }}'
type {{ .RepoName }} struct {
    Db db_manager.IDb
    QueryBuilder I{{ .RepoName }}QueryBuilder
    {{- if .DoesTableGenApprovalTable }}
    {{ .Name }}DraftRepository I{{ .Name }}DraftRepository
    {{ .Name }}DraftActivityLogRepository I{{ .Name }}DraftActivityLogRepository
    {{ .Name }}DraftItemRepository I{{ .Name }}DraftItemRepository
    {{- end }}
}

// {{ .RepoName }}QueryBuilder is responsible for building the queries for '{{ $table }}'
type {{ .RepoName }}QueryBuilder struct {
}

var  New{{ .RepoName }} = wire.NewSet(
    wire.Struct(new({{ .RepoName }}), "*"),
    wire.Struct(new({{ .RepoName }}QueryBuilder), "*"),
    wire.Bind(new(I{{ .RepoName }}), new({{ .RepoName }})),
    wire.Bind(new(I{{ .RepoName }}QueryBuilder), new({{ .RepoName }}QueryBuilder)),
    {{ if .DoesTableGenApprovalTable -}} wire.Bind(new(I{{ .Name }}CRRepository), new({{ .RepoName }})), {{- end }}
)

{{ if .PrimaryKey }}

// Insert inserts the {{ .Name }}Create to the database.
func ({{ $shortRepo }} *{{ .RepoName }}) Insert{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}Create) (*entities.{{ .Name }}, error) {
    return {{ $shortRepo }}.Insert{{ .Name }}WithSuffix(ctx, {{ $short }}, nil)
}

func ({{ $shortRepo }} *{{ .RepoName }}) Insert{{ .Name }}WithSuffix(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (*entities.{{ .Name }}, error) {
	var err error

    // retrieve id
	id, err := {{ $shortRepo }}.Insert{{ .Name }}IDResult(ctx, {{ $short }}, suffix)
	if err != nil {
		return nil, err
	}

    {{ if .DoesTableGenAuditLogsTable }}
    if err = {{ $shortRepo }}.InsertAuditLog(ctx, int(id), Insert); err != nil {
        return nil, err
    }
    {{- end }}

	new{{ $short }} := entities.{{ .Name }}{}

	err = {{ $shortRepo }}.Db.Get(ctx, &new{{ $short }}, sq.Expr("SELECT * FROM `{{ $table }}` WHERE `{{ .PrimaryKey.Col.ColumnName }}` = ?", id))

	return &new{{ $short }}, errors.Wrap(err, "error in {{ .RepoName }}")
}

func ({{ $shortRepo }} *{{ .RepoName }}) Insert{{ .Name }}IDResult(ctx context.Context, {{ $short }} entities.{{ .Name }}Create, suffix sq.Sqlizer) (int64, error) {
	var err error

{{ if .Table.ManualPk  }}
	// sql insert query, primary key must be provided
	qb := sq.Insert("`{{ $table }}`").Columns(
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
            "`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
    ).Values(
         {{- range .Fields }}
         {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
             {{ $short }}.{{ .Name }},
         {{- end }}
         {{- end }}
    )
    if suffix != nil {
        suffixQuery, suffixArgs, suffixErr := suffix.ToSql()
        if suffixErr != nil {
            return 0, suffixErr
        }
        qb.Suffix(suffixQuery, suffixArgs...)
    }

	// run query
	res, err := {{ $shortRepo }}.Db.Exec(ctx, qb)
	if err != nil {
		return 0, errors.Wrap(err, "error in {{ .RepoName }}")
	}

{{ else }}
	// sql insert query, primary key provided by autoincrement
	qb := sq.Insert("`{{ $table }}`").Columns(
	    {{- range .Fields }}
	    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
            "`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
	).Values(
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
            {{ $short }}.{{ .Name }},
        {{- end }}
        {{- end }}
	)
	if suffix != nil {
        suffixQuery, suffixArgs, suffixErr := suffix.ToSql()
        if suffixErr != nil {
            return 0, suffixErr
        }
        qb.Suffix(suffixQuery, suffixArgs...)
    }

	// run query
	res, err := {{ $shortRepo }}.Db.Exec(ctx, qb)
	if err != nil {
		return 0, errors.Wrap(err, "error in {{ .RepoName }}")
	}
{{ end }}

    // retrieve id
	id, err := res.LastInsertId()
	if err != nil {
		return 0, errors.Wrap(err, "error in {{ .RepoName }}")
	}

    return id, nil
}

{{ if .DoesTableGenAuditLogsTable }}
func ({{ $shortRepo }} *{{ .RepoName }}) InsertAuditLog(ctx context.Context, id int, action AuditLogAction) error {
	user := context_manager.GetUserContext(ctx)
    IDUserSelect := "NULL AS `audit_fk_user`"
    if user != nil {
        IDUserSelect = strconv.Itoa(user.ID)+" AS `audit_fk_user`"
    }
    selectForInsertQb := sq.Select(
        "`{{ $table }}`.`{{ $primaryKey.Col.ColumnName }}` AS `{{ $table }}_id`",
        IDUserSelect,
        "'"+string(action)+"' AS `audit_action`",
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
            "`{{ $table }}`.`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
        ).From("`{{ $table }}`").Where(sq.Eq{"`{{ $table }}`.`{{ $primaryKey.Col.ColumnName }}`": id})
    qb := sq.Insert("`{{ $table }}_audit_log`").Columns(
        `{{ $table }}_id`,
        `audit_fk_user`,
        `audit_action`,
        {{- range .Fields }}
        {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Name $primaryKey.Name) (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
            "`{{ .Col.ColumnName }}`",
        {{- end }}
        {{- end }}
    ).Select(selectForInsertQb)

	_, err := {{ $shortRepo }}.Db.Exec(ctx, qb)
	return err
}
{{ end }}

{{ if ne (fieldnamesmulti .Fields $short .PrimaryKeyFields) "" }}
	// Update updates the {{ .Name }}Create in the database.
	func ({{ $shortRepo }} *{{ .RepoName }}) Update{{ .Name }}ByFields(ctx context.Context, {{- range .PrimaryKeyFields }}{{ .Name }} {{ retype .Type }}{{- end }}, {{ $short }} entities.{{ .Name }}Update) (*entities.{{ .Name }}, error) {
		var err error

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

        // run query
        _, err = {{ $shortRepo }}.Db.Exec(ctx, qb)
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

        result := entities.{{ .Name }}{}
        err = {{ $shortRepo }}.Db.Get(ctx, &result, selectQb)

        {{- if .DoesTableGenAuditLogsTable }}
        if err = {{ $shortRepo }}.InsertAuditLog(ctx, {{ $primaryKey.Name }}, Update); err != nil {
            return nil, err
        }
        {{ end }}
        return &result, errors.Wrap(err, "error in {{ .RepoName }}")
	}

    // Update updates the {{ .Name }} in the database.
	func ({{ $shortRepo }} *{{ .RepoName }}) Update{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) (*entities.{{ .Name }}, error) {
    		var err error

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

            // run query
            _, err = {{ $shortRepo }}.Db.Exec(ctx, qb)
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

            result := entities.{{ .Name }}{}
            err = {{ $shortRepo }}.Db.Get(ctx, &result, selectQb)

            {{- if .DoesTableGenAuditLogsTable }}
            if err = {{ $shortRepo }}.InsertAuditLog(ctx, {{ $short }}.{{ $primaryKey.Name }}, Update); err != nil {
                return nil, err
            }
            {{ end }}
            return &result, errors.Wrap(err, "error in {{ .RepoName }}")
    	}
{{ else }}
	// Update statements omitted due to lack of fields other than primary key
{{ end }}

// Delete deletes the {{ .Name }} from the database.
func ({{ $shortRepo }} *{{ .RepoName }}) Delete{{ .Name }}(ctx context.Context, {{ $short }} entities.{{ .Name }}) error {
	var err error

    {{ if .HasActiveField }}
    qb := sq.Update("`{{ $table }}`").Set("active", false)
    {{ else }}
    {{- if .DoesTableGenAuditLogsTable }}
    if err = {{ $shortRepo }}.InsertAuditLog(ctx, {{ $short }}.{{ $primaryKey.Name }}, Delete); err != nil {
        return err
    }
    {{ end }}
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

    // run query
    _, err = {{ $shortRepo }}.Db.Exec(ctx, qb)
    if err != nil {
        return errors.Wrap(err, "error in {{ .RepoName }}")
    }
    {{- if .HasActiveField }}
    {{- if .DoesTableGenAuditLogsTable }}
    if err = {{ $shortRepo }}.InsertAuditLog(ctx, {{ $short }}.{{ $primaryKey.Name }}, Delete); err != nil {
        return errors.Wrap(err, "error in {{ .RepoName }}")
    }
    {{- end }}
    {{- end }}
    return errors.Wrap(err, "error in {{ .RepoName }}")
}

{{ if eq ( len .PrimaryKeyFields ) 1 }}
func ({{ $shortRepo }} *{{ .RepoName }}) Delete{{ .Name }}By{{ $primaryKey.Name }}(ctx context.Context, id {{ $primaryKey.Type }}) (bool, error) {
    var err error

    {{ if .HasActiveField }}
    qb := sq.Update("`{{ $table }}`").Set("active", false)
    {{ else }}
    {{- if .DoesTableGenAuditLogsTable }}
    if err = {{ $shortRepo }}.InsertAuditLog(ctx, {{ $short }}.{{ $primaryKey.Name }}, Delete); err != nil {
        return false, err
    }
    {{ end }}
    qb := sq.Delete("`{{ $table }}`")
    {{ end -}}

    qb = qb.Where(sq.Eq{"`{{ colname $primaryKey.Col}}`": id})

    // run query
    _, err = {{ $shortRepo }}.Db.Exec(ctx, qb)
    if err != nil {
        return false, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    {{- if .HasActiveField }}
    {{- if .DoesTableGenAuditLogsTable }}
    if err = {{ $shortRepo }}.InsertAuditLog(ctx, id, Delete); err != nil {
        return false, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    {{- end }}
    {{- end }}
    return err == nil, errors.Wrap(err, "error in {{ .RepoName }}")
}
{{- end }}

func ({{ $shortRepo }} *{{ .RepoName }}) FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string, suffixes ...sq.Sqlizer) (*sq.SelectBuilder, error) {
    return {{ $shortRepo }}.QueryBuilder.FindAll{{ .Name }}BaseQuery(ctx, filter, fields, suffixes...)
}

func ({{ $shortRepo }} *{{ .RepoName }}QueryBuilder) FindAll{{ .Name }}BaseQuery(ctx context.Context, filter *entities.{{ .Name }}Filter, fields string, suffixes ...sq.Sqlizer) (*sq.SelectBuilder, error) {
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

        qb, err = addAdditionalFilter(qb, filter.Wheres, filter.Joins, filter.LeftJoins, filter.GroupBys, filter.Havings)
        if err != nil {
            return qb, err
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

    for _, suffix := range suffixes {
        query, args, err := suffix.ToSql()
        if err != nil {
            return qb, err
        }
        qb.Suffix(query, args...)
    }

    return qb, nil
}

func ({{ $shortRepo }} *{{ .RepoName }}) AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error) {
    return {{ $shortRepo }}.QueryBuilder.AddPagination(ctx, qb, pagination)
}

func ({{ $shortRepo }} *{{ .RepoName }}QueryBuilder) AddPagination(ctx context.Context, qb *sq.SelectBuilder, pagination *entities.Pagination) (*sq.SelectBuilder, error) {
    fields := []string {
        {{- range .Fields }}
            {{- if ne .Col.IsVirtualFromConfig true }}
                "{{ .Col.ColumnName }}",
            {{- end }}
        {{- end }}
    }
    return AddPagination(qb, pagination, fields)
}

func ({{ $shortRepo }} *{{ .RepoName }}) FindAll{{ .Name }}(ctx context.Context, filter *entities.{{ .Name }}Filter, pagination *entities.Pagination) (list entities.List{{ .Name }}, err error) {
    return {{ $shortRepo }}.FindAll{{ .Name }}WithSuffix(ctx, filter, pagination)
}

func ({{ $shortRepo }} *{{ .RepoName }}) FindAll{{ .Name }}WithSuffix(ctx context.Context, filter *entities.{{ .Name }}Filter, pagination *entities.Pagination, suffixes ...sq.Sqlizer) (list entities.List{{ .Name }}, err error) {
    qb, err := {{ $shortRepo }}.FindAll{{ .Name }}BaseQuery(ctx, filter, "`{{ $table }}`.*", suffixes...)
    if err != nil {
        return entities.List{{ .Name }}{}, errors.Wrap(err, "error in {{ .RepoName }}")
    }
    qb, err = {{ $shortRepo }}.AddPagination(ctx, qb, pagination)
    if err != nil {
        return entities.List{{ .Name }}{}, errors.Wrap(err, "error in {{ .RepoName }}")
    }

    err = {{ $shortRepo }}.Db.Select(ctx, &list.Data, qb)

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
    err = {{ $shortRepo }}.Db.Get(ctx, &listMeta, qb)

    list.TotalCount = listMeta.Count

    return list, errors.Wrap(err, "error in {{ .RepoName }}")
}
{{- end }}

{{ if .DoesTableGenApprovalTable }}
func ({{ $shortRepo }} *{{ .RepoName }}) Approve{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark *string) (bool, error) {
    user := context_manager.GetUserContext(ctx)
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
    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByIDWithSuffix(ctx, IDDraft, nil, consts.SqlForUpdate)
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

    {{ range .DraftFields }}
        {{- if .IsEnum }}
            activityLog{{ .FieldName }}, err := entities.{{ $name }}DraftActivityLog{{ .FieldName }}FromString(draft.{{ .FieldName }}.String())
            if err != nil {
                return false, err
            }
        {{- end }}
    {{- end }}

    if _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkApprover,
        Status: entities.{{ .Name }}DraftActivityLogStatusApproved,
        Remark: remarkNullStr,
        {{- range .DraftFields }}
            {{- if .IsEnum }}
                {{ .FieldName }}: activityLog{{ .FieldName }},
            {{- else }}
                {{ .FieldName }}: draft.{{ .FieldName }},
            {{- end }}
        {{- end }}
    }); err != nil {
        return false, err
    }

    draftItems, err := {{ $shortRepo }}.{{ .Name }}DraftItemRepository.FindAll{{ .Name }}DraftItemWithSuffix(ctx, &entities.{{ .Name }}DraftItemFilter{
        FkDraft: entities.FilterOnField{{`{{ entities.Eq: IDDraft }}`}},
        {{- if .IsIncludeInactiveOnMove }}
        Active: entities.FilterOnField{{`{{ entities.Eq: []interface{}{false, true} }}`}},
        {{- end }}
    }, nil, consts.SqlForUpdate)
    if err != nil {
        return false, err
    }

    for _, draftItem := range draftItems.Data {
        item := entities.{{ .Name }}Create{
            {{- range .Fields }}
                {{- if ne .Name $primaryKey.Name }}
                    {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
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
                {{- if and (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") (ne .Col.IsGenerated true) (ne .Col.DisableForCreate true) }}
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

        newItem, err := {{ $shortRepo }}.Insert{{ .Name }}WithSuffix(ctx, item, onDuplicate)
        if err != nil {
            return false, err
        }

        draftItem.Fk{{ .Name }} = util.NewNullInt64(int64(newItem.ID))
        if _, err = {{ $shortRepo}}.{{ .Name }}DraftItemRepository.Update{{ .Name }}DraftItem(ctx, draftItem); err != nil {
            return false, err
        }
    }
    return true, nil
}

func ({{ $shortRepo }} *{{ .RepoName }}) Reject{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error) {
    user := context_manager.GetUserContext(ctx)
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

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByIDWithSuffix(ctx, IDDraft, nil, consts.SqlForUpdate)
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

    {{ range .DraftFields }}
        {{- if .IsEnum }}
            activityLog{{ .FieldName }}, err := entities.{{ $name }}DraftActivityLog{{ .FieldName }}FromString(draft.{{ .FieldName }}.String())
            if err != nil {
                return false, err
            }
        {{- end }}
    {{- end }}

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkApprover,
        Status: entities.{{ .Name }}DraftActivityLogStatusRejected,
        Remark: sql.NullString{Valid: true, String: remark},
        {{- range .DraftFields }}
            {{- if .IsEnum }}
                {{ .FieldName }}: activityLog{{ .FieldName }},
            {{- else }}
                {{ .FieldName }}: draft.{{ .FieldName }},
            {{- end }}
        {{- end }}
    })
    return err == nil, err
}

func ({{ $shortRepo }} *{{ .RepoName }}) Cancel{{ .Name }}ChangeRequest(ctx context.Context, IDDraft int, remark string) (bool, error) {
    user := context_manager.GetUserContext(ctx)
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

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByIDWithSuffix(ctx, IDDraft, nil, consts.SqlForUpdate)
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

    {{ range .DraftFields }}
        {{- if .IsEnum }}
            activityLog{{ .FieldName }}, err := entities.{{ $name }}DraftActivityLog{{ .FieldName }}FromString(draft.{{ .FieldName }}.String())
            if err != nil {
                return false, err
            }
        {{- end }}
    {{- end }}

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkUser,
        Status: entities.{{ .Name }}DraftActivityLogStatusCancelled,
        Remark: sql.NullString{Valid: true, String: remark},
        {{- range .DraftFields }}
            {{- if .IsEnum }}
                {{ .FieldName }}: activityLog{{ .FieldName }},
            {{- else }}
                {{ .FieldName }}: draft.{{ .FieldName }},
            {{- end }}
        {{- end }}
    })
    return err == nil, err
}

func ({{ $shortRepo }} *{{ .RepoName }}) Submit{{ .Name }}Draft(ctx context.Context, IDDraft int, remark *string) (bool, error) {
    user := context_manager.GetUserContext(ctx)
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

    draft, err := {{ $shortRepo }}.{{ .Name }}DraftRepository.{{ .Name }}DraftByIDWithSuffix(ctx, IDDraft, nil, consts.SqlForUpdate)
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

    {{ range .DraftFields }}
        {{- if .IsEnum }}
            activityLog{{ .FieldName }}, err := entities.{{ $name }}DraftActivityLog{{ .FieldName }}FromString(draft.{{ .FieldName }}.String())
            if err != nil {
                return false, err
            }
        {{- end }}
    {{- end }}

    _, err = {{ $shortRepo }}.{{ .Name }}DraftActivityLogRepository.Insert{{ .Name }}DraftActivityLog(ctx, entities.{{ .Name }}DraftActivityLogCreate{
        FkDraft: IDDraft,
        FkUser: fkUser,
        Status: entities.{{ .Name }}DraftActivityLogStatusPending,
        Remark: remarkNullStr,
        {{- range .DraftFields }}
            {{- if .IsEnum }}
                {{ .FieldName }}: activityLog{{ .FieldName }},
            {{- else }}
                {{ .FieldName }}: draft.{{ .FieldName }},
            {{- end }}
        {{- end }}
    })
    return err == nil, err
}

{{ end }}
