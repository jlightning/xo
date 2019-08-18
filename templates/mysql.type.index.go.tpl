{{- if eq ( len .Fields ) 1 }}
    {{- if .Index.IsUnique }}
    func (l *List{{ .Type.Name }}) MapBy{{ (index .Fields 0).Name }}() (m map[{{ (index .Fields 0).Type }}]{{ .Type.Name }}) {
        m = make (map[{{ (index .Fields 0).Type }}]{{ .Type.Name }}, len(l.Data))
        for _, item := range l.Data {
            m[item.{{ (index .Fields 0).Name }}] = item
        }
        return m
    }
    {{- else }}
    func (l *List{{ .Type.Name }}) MapBy{{ (index .Fields 0).Name }}() (m map[{{ (index .Fields 0).Type }}]List{{ .Type.Name }}) {
        m = make (map[{{ (index .Fields 0).Type }}]List{{ .Type.Name }})
        for _, item := range l.Data {
            list := m[item.{{ (index .Fields 0).Name }}]
            list.Data = append(list.Data, item)

            m[item.{{ (index .Fields 0).Name }}] = list
        }
        for k, v := range m {
            v.TotalCount = len(v.Data)
            m[k] = v
        }
        return m
    }
    {{- end }}
{{- end }}
