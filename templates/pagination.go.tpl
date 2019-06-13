type Pagination struct {
	Page       *int
	PerPage    *int
	Sort       []string
	CustomSort []string
}

func NewPagination(page int, perPage int, sort []string, customSort []string) *Pagination {
	return &Pagination{Page: &page, PerPage: &perPage, Sort: sort, CustomSort: customSort}
}

type ListMetadata struct {
    Count int `db:"count"`
}
