//go:build !with_gvisor

package engine

// withGvisor: the mixed and gvisor TUN stacks need mihomo built with
// -tags with_gvisor. Without it mihomo only logs an error and runs on
// without TUN, so we refuse up front instead.
const withGvisor = false
