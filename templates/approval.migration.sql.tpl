-- +goose Up
{{- $primaryKey := .PrimaryKey }}
CREATE TABLE IF NOT EXISTS `{{ .Table.TableName}}_draft` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `fk_school` INT NOT NULL,
    `fk_centre` INT,
    `fk_class` INT,
    `fk_user` INT NOT NULL,
    `fk_approver` INT,
    `status` ENUM('draft', 'pending', 'approved', 'rejected', 'cancelled') NOT NULL DEFAULT 'draft',
    `label` VARCHAR(255),
    `remark` VARCHAR(255),
    `active` BOOLEAN NOT NULL DEFAULT true,
    `created_at` timestamp DEFAULT CURRENT_TIMESTAMP,
    `updated_at` timestamp DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    FOREIGN KEY (`fk_school`) REFERENCES `school`(`id`) ON DELETE NO ACTION,
    FOREIGN KEY (`fk_centre`) REFERENCES `centre`(`id`) ON DELETE NO ACTION,
    FOREIGN KEY (`fk_class`) REFERENCES `class`(`id`) ON DELETE NO ACTION,
    FOREIGN KEY (`fk_user`) REFERENCES `user`(`id`) ON DELETE NO ACTION,
    FOREIGN KEY (`fk_approver`) REFERENCES `user`(`id`) ON DELETE NO ACTION
) ENGINE=INNODB;

CREATE TABLE IF NOT EXISTS `{{ .Table.TableName}}_draft_item` (
    `id` INT NOT NULL AUTO_INCREMENT,
    `fk_draft` INT NOT NULL,
    {{- range .Fields }}
        {{- if ne .Name $primaryKey.Name }}
        {{- if ne .Col.IsGenerated true }}
        {{- if ne .Col.IsVirtualFromConfig true }}
    `{{ .Col.ColumnName }}` {{ upperCaseMysqlType .Col.RealDataType }} {{- if .Col.NotNull }} NOT NULL {{- end -}}
        {{- if .Col.DefaultValue.Valid }} DEFAULT {{ .Col.DefaultValue.String }} {{- end -}},
        {{- end }}
        {{- end }}
        {{- end }}
    {{- end }}
    PRIMARY KEY (`id`),
    {{- range .ForeignKeyGroup.ManyToOneKeys }}
    FOREIGN KEY (`{{ .Field.Col.ColumnName }}`) REFERENCES `{{ .RefType.Table.TableName }}`(`{{ .RefField.Col.ColumnName }}`),
    {{- end }}
    FOREIGN KEY (`fk_draft`) REFERENCES `{{ .Table.TableName}}_draft`(`id`) ON DELETE NO ACTION
) ENGINE=INNODB;