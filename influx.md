
qbthost variable
```
import "influxdata/influxdb/schema"
schema.tagValues(
    bucket: "qbt",
    tag: "host"
)
```


sample query
```
from(bucket: "qbt")
  |> range(start: v.timeRangeStart, stop: v.timeRangeStop)
  |> filter(fn: (r) => r["host"] =~ /^${qbthost:regex}$/ )
  |> filter(fn: (r) => r["_measurement"] == "stalledUP")
  |> filter(fn: (r) => r["_field"] == "value")
```
