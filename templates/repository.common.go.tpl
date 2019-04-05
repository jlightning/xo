type AuditLogAction string

const (
    Insert AuditLogAction = "insert"
    Update = "update"
    Delete = "delete"
)

func addFilter(qb *sq.SelectBuilder, columnName string, filterOnField entities.FilterOnField) (*sq.SelectBuilder, error) {
    for _, filterList := range filterOnField {
        for filterType, v := range filterList {
            switch filterType {
            case entities.Eq:
                qb = qb.Where(sq.Eq{columnName: v})
            case entities.Neq:
                qb = qb.Where(sq.NotEq{columnName: v})
            case entities.Gt:
                qb = qb.Where(sq.Gt{columnName: v})
            case entities.Gte:
                qb = qb.Where(sq.GtOrEq{columnName: v})
            case entities.Lt:
                qb = qb.Where(sq.Lt{columnName: v})
            case entities.Lte:
                qb = qb.Where(sq.LtOrEq{columnName: v})
            case entities.Like:
                qb = qb.Where(columnName + " LIKE ?", v)
            case entities.Between:
                if arrv, ok := v.([]interface{}); ok && len(arrv) == 2 {
                    qb = qb.Where(columnName + " BETWEEN ? AND ?", arrv...)
                }
            case entities.Raw:
                if sqlizer, ok := v.(sq.Sqlizer); ok {
                    query, args, err := sqlizer.ToSql()
                    if err != nil {
                        return qb, err
                    }
                    qb.Where("("+columnName+" "+query+")", args...)
                } else {
                    qb.Where("(" + columnName + " " + fmt.Sprint(v) + ")")
                }
            }
        }
    }
    return qb, nil
}

func addPagination(qb *sq.SelectBuilder, pagination *entities.Pagination, sortFieldMap map[string]string) (*sq.SelectBuilder, error){
	if pagination != nil {
		if pagination.Page != nil && pagination.PerPage != nil {
			offset := uint64((*pagination.Page - 1) * *pagination.PerPage)
			qb = qb.Offset(offset).Limit(uint64(*pagination.PerPage))
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
			orderBy := strings.Join(orderStrs, ", ")
			if orderBy != "" {
				qb = qb.OrderBy(strings.Join(orderStrs, ", "))
			}
		}
	}
	return qb, nil
}
