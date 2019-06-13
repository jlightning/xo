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

func addPagination(qb *sq.SelectBuilder, pagination *entities.Pagination, sortFieldMap map[string]string) (*sq.SelectBuilder, error) {
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
