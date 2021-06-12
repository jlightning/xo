type AuditLogAction string

const (
	Insert AuditLogAction = "insert"
	Update                = "update"
	Delete                = "delete"
)

func AddFilterToQb(qb *sq.SelectBuilder, columnName string, filterOnField entities.FilterOnField) (*sq.SelectBuilder, error) {
    return addFilter(qb, columnName, filterOnField)
}

func addFilter(qb *sq.SelectBuilder, columnName string, filterOnField entities.FilterOnField) (*sq.SelectBuilder, error) {
	sqlizer, err := FilterOnFieldToSqlizer(columnName, filterOnField)
	if err != nil {
		return nil, err
	}
	if sqlizer != nil {
		qb.Where(sqlizer)
	}
	return qb, nil
}

func addAdditionalFilter(qb *sq.SelectBuilder, wheres, joins, leftJoins []sq.Sqlizer, groupBys []string, havings []sq.Sqlizer) (*sq.SelectBuilder, error) {
	if wheres != nil {
		for _, where := range wheres {
			query, args, err := where.ToSql()
			if err != nil {
				return qb, err
			}
			qb = qb.Where(query, args...)
		}
	}
	if joins != nil {
		for _, join := range joins {
			query, args, err := join.ToSql()
			if err != nil {
				return qb, err
			}
			qb = qb.Join(query, args...)
		}
	}
	if leftJoins != nil {
		for _, leftJoin := range leftJoins {
			query, args, err := leftJoin.ToSql()
			if err != nil {
				return qb, err
			}
			qb = qb.LeftJoin(query, args...)
		}
	}
	if groupBys != nil {
		qb = qb.GroupBy(groupBys...)
	}
	if havings != nil {
		for _, item := range havings {
			query, args, err := item.ToSql()
			if err != nil {
				return qb, err
			}
			qb = qb.Having(query, args...)
		}
	}

	return qb, nil
}

func FilterOnFieldToSqlizer(columnName string, filterOnField entities.FilterOnField) (sq.Sqlizer, error) {
	var combined sq.And
	for _, filterList := range filterOnField {
		for filterType, v := range filterList {
			switch filterType {
			case entities.Eq:
				combined = append(combined, sq.Eq{columnName: v})
			case entities.Neq:
				combined = append(combined, sq.NotEq{columnName: v})
			case entities.Gt:
				combined = append(combined, sq.Gt{columnName: v})
			case entities.Gte:
				combined = append(combined, sq.GtOrEq{columnName: v})
			case entities.Lt:
				combined = append(combined, sq.Lt{columnName: v})
			case entities.Lte:
				combined = append(combined, sq.LtOrEq{columnName: v})
			case entities.Like:
				combined = append(combined, sq.Expr(columnName+" LIKE ?", v))
			case entities.Between:
				if arrv, ok := v.([]interface{}); ok && len(arrv) == 2 {
					combined = append(combined, sq.Expr(columnName+" BETWEEN ? AND ?", arrv...))
				} else {
					return nil, errors.New("invalid between filter")
				}
            }
		}
	}
	// return nil interface when underlying type is nil
	if combined == nil {
		return nil, nil
	}
	return combined, nil
}

func AddPagination(qb *sq.SelectBuilder, pagination *entities.Pagination, tableName string, fields []string) (*sq.SelectBuilder, error) {
	return AddPaginationWithSortFieldMap(qb, pagination, GetSortFieldMapFromFields(tableName, fields))
}

func GetSortFieldMapFromFields(tableName string, fields []string) map[string]string {
	tableName = strings.Trim(tableName, "`")
	tablePrefix := ""
	if len(tableName) != 0 {
		tablePrefix = "`" + tableName + "`."
	}
	sortFieldMap := make(map[string]string, len(fields)*4)
	for _, field := range fields {
		colName := strings.Trim(field, "`")
		for _, c := range colName {
			if c >= 'A' && c <= 'Z' {
				colName = snaker.CamelToSnake(colName)
				break
			}
		}
		lowerCamel := snaker.ForceLowerCamelIdentifier(colName)

		sortFieldMap[lowerCamel] = tablePrefix + "`" + colName + "` ASC"
		sortFieldMap["-"+lowerCamel] = tablePrefix + "`" + colName + "` DESC"

		if colName == "id" {
			sortFieldMap["ID"] = tablePrefix + "`" + colName + "` ASC"
			sortFieldMap["-ID"] = tablePrefix + "`" + colName + "` DESC"
		}

		sortFieldMap[colName] = tablePrefix + "`" + colName + "` ASC"
		sortFieldMap["-"+colName] = tablePrefix + "`" + colName + "` DESC"
	}
	return sortFieldMap
}

func AddPaginationWithSortFieldMap(qb *sq.SelectBuilder, pagination *entities.Pagination, sortFieldMap map[string]string) (*sq.SelectBuilder, error) {
	if pagination != nil {
		if pagination.Page != nil && pagination.PerPage != nil {
			offset := uint64((*pagination.Page - 1) * *pagination.PerPage)
			qb = qb.Offset(offset).Limit(uint64(*pagination.PerPage))
		}
		if pagination.CustomSort != nil {
			qb = qb.OrderBy(pagination.CustomSort...)
		}
		if pagination.Sort != nil {
			var orderStrs []string
			for _, field := range pagination.Sort {
				if orderStr, ok := sortFieldMap[field]; ok {
					orderStrs = append(orderStrs, orderStr)
				} else {
					return qb, errors.New("doesnt allow sorting on field `" + field + "` not found")
				}
			}
			qb = qb.OrderBy(orderStrs...)
		}
	}
	return qb, nil
}

func addAuditLog(ctx context.Context, db db_manager.IDb, table string, tableID int, action AuditLogAction, data interface{}) error {
	user, userID := context_manager.GetUserContext(ctx), (*int)(nil)
	if user != nil {
		userID = &user.ID
	}
	dataJson, err := json.Marshal(data)
	if err != nil {
		return err
	}

	qb := sq.Insert("audit_log").Columns("entity_name", "entity_id", "audit_fk_user", "audit_action", "data").
		Values(table, tableID, userID, action, dataJson)
	_, err = db.Exec(ctx, qb)
	return err
}

func isInterfaceNil(a interface{}) bool {
    return a == nil || (reflect.ValueOf(a).Kind() == reflect.Ptr && reflect.ValueOf(a).IsNil())
}
