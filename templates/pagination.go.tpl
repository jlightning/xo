type Pagination struct {
	Page    *int
	PerPage *int
	Sort    []string
}

func NewPagination(page int, perPage int, sort []string) *Pagination {
	return &Pagination{Page: &page, PerPage: &perPage, Sort: sort}
}

func (p *Pagination) Hash() (string, error) {
	h := md5.New()
	if p.Page != nil {
		if _, err := io.WriteString(h, "page -> "+strconv.Itoa(*p.Page)); err != nil {
			return "", err
		}
	}
	if p.PerPage != nil {
		if _, err := io.WriteString(h, "perPage -> "+strconv.Itoa(*p.PerPage)); err != nil {
			return "", err
		}
	}
	if _, err := io.WriteString(h, "sort -> "+strings.Join(p.Sort, ",")); err != nil {
		return "", err
	}
	return fmt.Sprintf("%x", h.Sum(nil)), nil
}

type ListMetadata struct {
    Count int `db:"count"`
}
