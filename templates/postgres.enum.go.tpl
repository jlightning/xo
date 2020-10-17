{{- $type := .Name -}}
{{- $short := (shortname $type "enumVal" "text" "buf" "ok" "src") -}}
{{- $reverseNames := .ReverseConstNames -}}
// {{ $type }} is the '{{ .Enum.EnumName }}' enum type from schema '{{ .Schema  }}'.
type {{ $type }} uint16

const (
{{- range .Values }}
	// {{ if $reverseNames }}{{ .Name }}{{ $type }}{{ else }}{{ $type }}{{ .Name }}{{ end }} is the '{{ .Val.EnumValue }}' {{ $type }}.
	{{ if $reverseNames }}{{ .Name }}{{ $type }}{{ else }}{{ $type }}{{ .Name }}{{ end }} = {{ $type }}({{ .Val.ConstValue }})
{{ end -}}
)

// String returns the string value of the {{ $type }}.
func ({{ $short }} {{ $type }}) String() string {
	var enumVal string

	switch {{ $short }} {
{{- range .Values }}
	case {{ if $reverseNames }}{{ .Name }}{{ $type }}{{ else }}{{ $type }}{{ .Name }}{{ end }}:
		enumVal = "{{ .Val.EnumValue }}"
{{ end -}}
	}

	return enumVal
}

// MarshalGQL implements the graphql.Marshaler interface
func ({{ $short }} {{ $type }}) MarshalGQL(w io.Writer) {
	w.Write([]byte(`"` + {{ $short }}.String() + `"`))
}

// UnmarshalGQL implements the graphql.Marshaler interface
func ({{ $short }} *{{ $type }}) UnmarshalGQL(v interface{}) error {
	if str, ok := v.(string); ok {
		return {{ $short }}.UnmarshalText([]byte(str))
	}
	return errorx.ErrInvalidEnumGraphQL.AddExtra("type", "{{ $type }}").Build()
}

// MarshalText marshals {{ $type }} into text.
func ({{ $short }} {{ $type }}) MarshalText() ([]byte, error) {
	return []byte({{ $short }}.String()), nil
}

// UnmarshalText unmarshals {{ $type }} from text.
func ({{ $short }} *{{ $type }}) UnmarshalText(text []byte) error {
	switch string(text)	{
{{- range .Values }}
	case "{{ .Val.EnumValue }}":
		*{{ $short }} = {{ if $reverseNames }}{{ .Name }}{{ $type }}{{ else }}{{ $type }}{{ .Name }}{{ end }}
{{ end }}

	default:
		return errorx.ErrInvalidEnumGraphQL.AddExtra("type", "{{ $type }}").Build()
	}

	return nil
}

// Value satisfies the sql/driver.Valuer interface for {{ $type }}.
func ({{ $short }} {{ $type }}) Value() (driver.Value, error) {
	return {{ $short }}.String(), nil
}

// Value satisfies the sql/driver.Valuer interface for {{ $type }}.
func ({{ $short }} {{ $type }}) Ptr() *{{ $type }} {
	return &{{ $short }}
}

// Scan satisfies the database/sql.Scanner interface for {{ $type }}.
func ({{ $short }} *{{ $type }}) Scan(src interface{}) error {
	buf, ok := src.([]byte)
	if !ok {
	   return errorx.ErrInvalidEnumScan.AddExtra("type", "{{ $type }}").Build()
	}

	return {{ $short }}.UnmarshalText(buf)
}

func {{ $type }}FromString(str string) ({{ $type }}, error) {
    var {{ $short }} {{ $type }}
    err := {{ $short }}.UnmarshalText([]byte(str))
    return {{ $short }}, err
}

