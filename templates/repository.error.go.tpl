var ErrRepo{{ .Name }}NotFound = errgen.NewBadRequestErr("{{ toEntityName .Name }} not found")
