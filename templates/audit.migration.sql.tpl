-- +goose Up
{{- $primaryKey := .PrimaryKey }}
CREATE TABLE IF NOT EXISTS `{{ .Table.TableName}}_audit_log` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `{{ .Table.TableName}}_id` INT NOT NULL,
    `audit_fk_user` INT,
    `audit_action` ENUM('insert', 'update', 'delete') NOT NULL,
    {{- range .Fields }}
        {{- if ne .Name $primaryKey.Name }}
        {{- if ne .Col.IsGenerated true }}
        {{- if ne .Col.IsVirtualFromConfig true }}
    `{{ .Col.ColumnName }}` {{ upperCaseMysqlType .Col.RealDataType }}
        {{- .Col.GetMysqlDefaultStr -}},
        {{- end }}
        {{- end }}
        {{- end }}
    {{- end }}
    PRIMARY KEY (`id`),
    {{- range .ForeignKeyGroup.ManyToOneKeys }}
    FOREIGN KEY (`{{ .Field.Col.ColumnName }}`) REFERENCES `{{ .RefType.Table.TableName }}`(`{{ .RefField.Col.ColumnName }}`),
    {{- end }}
    FOREIGN KEY (`audit_fk_user`) REFERENCES `user`(`id`) ON DELETE NO ACTION,
    FOREIGN KEY (`{{ .Table.TableName}}_id`) REFERENCES `{{ .Table.TableName}}`(`id`) ON DELETE NO ACTION
) ENGINE=INNODB;
