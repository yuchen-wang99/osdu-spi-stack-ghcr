# ADR-023: Application Insights for Service Telemetry

**Status**: Accepted

## Context

OSDU's Azure provider services are built on `core-lib-azure`, which registers an Application Insights request-telemetry filter at startup. With no connection string the filter dereferences a null configuration and the service NPEs before it serves traffic.

ADR-002 (now ADR-021) gives cluster-level Managed Prometheus and Container Insights, which cover node and container metrics and logs. They do not carry the per-request, per-service application traces and dependency calls that `core-lib-azure` is wired to emit, and they do not satisfy the agent's startup expectation of a connection string.

An interim fix wrote a dummy/disabled connection string to stop the NPE. That unblocks startup but produces no telemetry, so service-level failures stay invisible.

## Decision

Provision real Application Insights in `infra/main.bicep` and wire it to every service:

- A workspace-based **Application Insights** component (`Microsoft.Insights/components`, `kind: web`) linked to a **Log Analytics** workspace (`PerGB2018`, 30-day retention).
- The connection string is a Bicep output the CLI writes into the `osdu-config` ConfigMap as `APPLICATIONINSIGHTS_CONNECTION_STRING`, mounted into every service via `envFrom` (ADR-010).
- The `osdu-spi-service` chart sets `APPLICATIONINSIGHTS_ROLE_NAME` per service so each one is a distinct node on the Application Insights application map.

Provisioning is optional: an empty `appInsightsName` skips the component, and the CLI then falls back to a disabled connection string so `core-lib-azure` still does not NPE.

Rejected: dummy/disabled connection string as the end state. Silences the NPE but yields zero telemetry. Rejected: Container Insights only. No per-request APM or distributed tracing for the OSDU services. Rejected: a classic (non-workspace) Application Insights resource. Workspace-based is the supported shape and keeps logs and traces in one Log Analytics workspace.

## Consequences

- Every service emits real request, dependency, and exception telemetry, attributable per service via the cloud role name. The first deploy with this path came up NPE-free.
- One Application Insights component plus a Log Analytics workspace are added to the resource group; retention is capped at 30 days to bound cost.
- Telemetry is opt-out: a deploy that omits the Application Insights name still starts cleanly.
