package tracelab

import (
	"context"
	"go.opentelemetry.io/otel/attribute"
	"go.opentelemetry.io/otel/propagation"
	"go.opentelemetry.io/otel/trace"
)

// Chain is a synthetic in-memory propagation fixture, not Gin middleware or
// an installed collector. It deliberately does not propagate baggage.
func Chain(provider trace.TracerProvider, in propagation.TextMapCarrier) propagation.MapCarrier {
	p := propagation.TraceContext{}
	ctx := p.Extract(context.Background(), in)
	tracer := provider.Tracer("gopherforge.example/trace-lab")
	ctx, server := tracer.Start(ctx, "GET /orders/{id}", trace.WithSpanKind(trace.SpanKindServer))
	defer server.End()
	ctx, client := tracer.Start(ctx, "catalog.lookup", trace.WithSpanKind(trace.SpanKindClient))
	defer client.End()
	client.SetAttributes(attribute.String("catalog.result", "fixture"))
	out := propagation.MapCarrier{}
	p.Inject(ctx, out)
	return out
}
