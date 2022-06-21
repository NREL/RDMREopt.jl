# RDMREopt

## TODO
- [ ] save all results and inputs in JSON format
```javascript
{
  "reopt_version": x.x.x,
  "results": [
    {

    },
    ...
  ] 
  "base_scenario": {
    "Site": {
      "latitude": 31.25,
      ...
    },
    ...
  },
  "uncertainties": [
    {
      "Financial.offtaker_discount_rate": 0.12,
      "PV.size_kw": 134,
      ...
    },
    ...
  ] 
}
```
where `len(results["uncertainties"])` = `len(results["results"])`
- [ ] plot ranges, df.corr, hists of metrics and uncertainties
- [ ] add prob of survival metric for N time step outage
- [ ] return list of possible metrics