{{- $short := (shortname .Name "err" "res" "sqlstr" "db" "XOLog") -}}
{{- $table := (schema .Table.TableName) -}}
{{- $tableVar := .Table -}}
{{- $primaryKey := .PrimaryKey -}}
{{- $fkGroup := .ForeignKeyGroup -}}
{{- $this := . -}}
type {{ .Name }} {
{{- range .Fields }}
{{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInType }}
{{- if ne .GraphqlTypeExcluded true }}
    {{ lowerfirst .Name }}: {{ retypegraphql .Type }} {{- if .Col.NotNull }}!{{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- if $fkGroup }}

{{- range $fkGroup.ManyToOneKeys }}
{{- if and (ne .CallFuncName "") (ne ($this.IsGraphQLConnectionExcluded .RefType.Table.TableName) true) }}
    {{ lowerfirst .FuncName }}(filter: {{ .RefType.Name }}Filter): {{ .RefType.Name }} @filterModifier(from: "{{ $table }}")
{{- end }}
{{- end }}

{{- range $fkGroup.OneToManyKeys }}
{{- if and (ne .RevertCallFuncName "") (ne ($this.IsGraphQLConnectionExcluded .Type.Table.TableName) true) }}
    {{- if .IsUnique }}
    {{ lowerfirst .RevertFuncName }}(filter: {{ .Type.Name }}Filter): {{ .Type.Name }} @filterModifier(from: "{{ $table }}")
    {{- else }}
    {{ lowerfirst .RevertFuncName }}(filter: {{ .Type.Name }}Filter, pagination: Pagination): List{{ .Type.Name }}! @filterModifier(from: "{{ $table }}")
    {{- end }}
{{- end }}
{{- end }}
{{- end }}

{{- range $k, $v := .GraphQLIncludeFields }}
    {{$k}}{{$v}}
{{- end }}
}
input {{ .Name }}Filter {
{{- range .Fields }}
{{- if ne .GraphqlFilterExcluded true }}
{{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInFilter }}
    {{ lowerfirst .Name }}: FilterOnField
{{- end }}
{{- end }}
{{- end }}
}

{{- if canhavecreatestruct .Fields $primaryKey }}
input {{ .Name }}Create {
{{- range .Fields }}
{{- if ne .GraphqlCreateExcluded true }}
{{- if and (or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInCreate) (ne .Col.DisableForCreate true) }}
    {{- if and (or (ne .Col.ColumnName $primaryKey.Col.ColumnName) $tableVar.ManualPk) (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") }}
	{{ lowerfirst .Name }}: {{ retypegraphql .Type }}{{- if .Col.NotNull }}!{{- end }}
	{{- end }}
{{- end }}
{{- end }}
{{- end }}
}

input {{ .Name }}Update {
{{- range .Fields }}
{{- if ne .GraphqlUpdateExcluded true }}
{{- if or (ne .Col.IsVirtualFromConfig true) .Col.IsIncludeInUpdate }}
    {{- if and (or (ne .Col.ColumnName $primaryKey.Col.ColumnName) $tableVar.ManualPk) (ne .Col.ColumnName "created_at") (ne .Col.ColumnName "updated_at") }}
	{{ lowerfirst .Name }}: {{ retypegraphql .Type }}
	{{- end }}
{{- end }}
{{- end }}
{{- end }}
}
{{- end }}

type List{{ .Name }} {
    totalCount: Int!
    data: [{{ .Name }}!]!
}
