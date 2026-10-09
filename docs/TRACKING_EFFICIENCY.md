# Tracking efficiency

The app preserves Tracelet 3.7.5's balanced profile instead of replacing its nested settings with constructor defaults. This retains adaptive distance filtering, fused motion detection, periodic stationary tracking and the balanced Android location interval. The app uses a 25-metre movement filter, a two-minute stationary timeout, and three-minute stationary fixes and heartbeats. GPS remains high accuracy for movement and stationary speed detection.

The durable uploader independently samples movement, activity, battery/charging changes and heartbeats before sending. Offline points are batched and acknowledged; queue limits and leases bound storage and retries. These settings reduce requested sampling work but do not establish measured battery savings or guarantee update timing. Android and device manufacturers may defer execution.

Before release, measure a stationary eight-hour run and a moving one-hour route on supported devices, recording battery change, fix accuracy, capture-to-server delay and missed place transitions. Repeat with battery saver and background permission changes. Compare against the previous configuration on the same devices; do not infer runtime improvements from the configuration alone.
