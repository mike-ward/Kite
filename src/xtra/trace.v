module xtra

@[if !prod]
pub fn trace(s string) {
	eprintln(s)
}
