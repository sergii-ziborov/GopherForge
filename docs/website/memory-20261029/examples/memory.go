package memorylab

import (
	"bytes"
	"fmt"
	"strconv"
)

type Node struct {
	Left, Right *Node
	Payload     [48]byte
}

// BuildGraph uses the same Node type, object count and N-1 non-nil edges.
// The temporary construction index is not returned to the caller.
func BuildGraph(n int, shape string) *Node {
	if n <= 0 {
		return nil
	}
	nodes := make([]*Node, n)
	for i := range nodes {
		nodes[i] = new(Node)
	}
	switch shape {
	case "chain":
		for i := 0; i+1 < n; i++ {
			nodes[i].Left = nodes[i+1]
		}
	case "tree":
		for i := range nodes {
			if j := 2*i + 1; j < n {
				nodes[i].Left = nodes[j]
			}
			if j := 2*i + 2; j < n {
				nodes[i].Right = nodes[j]
			}
		}
	default:
		panic("unknown graph shape")
	}
	return nodes[0]
}

// GraphStats walks only the acyclic graphs produced by BuildGraph.
func GraphStats(root *Node) (count, depth int) {
	type item struct {
		n *Node
		d int
	}
	if root == nil {
		return 0, 0
	}
	stack := []item{{root, 1}}
	for len(stack) > 0 {
		v := stack[len(stack)-1]
		stack = stack[:len(stack)-1]
		count++
		if v.d > depth {
			depth = v.d
		}
		if v.n.Left != nil {
			stack = append(stack, item{v.n.Left, v.d + 1})
		}
		if v.n.Right != nil {
			stack = append(stack, item{v.n.Right, v.d + 1})
		}
	}
	return
}

//go:noinline
func RetainToken(mode string) []byte {
	backing := make([]byte, 16<<20)
	for i := range backing {
		backing[i] = byte(i)
	}
	switch mode {
	case "view":
		return backing[:32]
	case "clip":
		return backing[:32:32]
	case "copy":
		return CopyPrefix(backing, 32)
	default:
		panic("unknown token mode")
	}
}

func FormatEvent(id uint64, active bool) string {
	return fmt.Sprintf("id=%d active=%t", id, active)
}
func AppendEvent(id uint64, active bool) string {
	buf := make([]byte, 0, 48)
	buf = append(buf, "id="...)
	buf = strconv.AppendUint(buf, id, 10)
	buf = append(buf, " active="...)
	buf = strconv.AppendBool(buf, active)
	return string(buf)
}

// CopyPrefix returns an independent prefix; callers supply a valid length.
func CopyPrefix(buf []byte, n int) []byte { return bytes.Clone(buf[:n]) }
