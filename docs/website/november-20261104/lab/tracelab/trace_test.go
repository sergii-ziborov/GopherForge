package tracelab

import (
	"context"
	"go.opentelemetry.io/otel/propagation"
	sdk "go.opentelemetry.io/otel/sdk/trace"
	"go.opentelemetry.io/otel/sdk/trace/tracetest"
	"go.opentelemetry.io/otel/trace"
	"testing"
)

func TestParentChildPropagationAndNoBaggage(t *testing.T) {
	rec := tracetest.NewSpanRecorder()
	provider := sdk.NewTracerProvider(sdk.WithSpanProcessor(rec), sdk.WithSampler(sdk.AlwaysSample()))
	defer provider.Shutdown(context.Background())
	incoming := propagation.MapCarrier{"traceparent": "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01", "baggage": "secret=synthetic"}
	out := Chain(provider, incoming)
	ended := rec.Ended()
	if len(ended) != 2 {
		t.Fatal(len(ended))
	}
	client, server := ended[0], ended[1]
	if server.Parent().SpanID().String() != "00f067aa0ba902b7" || !server.Parent().IsRemote() || client.Parent().SpanID() != server.SpanContext().SpanID() {
		t.Fatal("parent chain lost")
	}
	got := trace.SpanContextFromContext(propagation.TraceContext{}.Extract(context.Background(), out))
	if got.TraceID() != server.SpanContext().TraceID() || got.SpanID() != client.SpanContext().SpanID() || out.Get("baggage") != "" {
		t.Fatal(out)
	}
}
func TestMalformedParentStartsFreshTrace(t *testing.T) {
	rec := tracetest.NewSpanRecorder()
	p := sdk.NewTracerProvider(sdk.WithSpanProcessor(rec))
	defer p.Shutdown(context.Background())
	Chain(p, propagation.MapCarrier{"traceparent": "not-a-trace"})
	ended := rec.Ended()
	if len(ended) != 2 || ended[1].Parent().IsValid() || !ended[1].SpanContext().IsValid() {
		t.Fatal("malformed parent accepted")
	}
}
