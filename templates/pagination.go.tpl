type Pagination struct {
	Page    *int
	PerPage *int
	Sort    []string
}

func NewPagination(page int, perPage int, sort []string) *Pagination {
	return &Pagination{Page: &page, PerPage: &perPage, Sort: sort}
}

type ListMetadata struct {
    Count int `db:"count"`
}
