"""Analyze saved, public Google Trends UI chart tables, never private endpoints."""
import csv, datetime as dt, json, pathlib, re, statistics
ROOT = pathlib.Path(__file__).resolve().parent
CHECKED = dt.date(2026, 10, 29)
def summarize(rows, checked=CHECKED):
    parsed=[]
    for raw, value in rows[1:]:
        date=dt.datetime.strptime(re.sub('[\u202a-\u202e]', '', raw), '%b %d, %Y').date()
        score=int(value)
        if not 0 <= score <= 100: raise ValueError('score outside normalized range')
        parsed.append((date,score))
    if any(b[0]-a[0] != dt.timedelta(days=7) for a,b in zip(parsed,parsed[1:])):
        raise ValueError('nonconsecutive weekly observations')
    complete=[r for r in parsed if r[0]+dt.timedelta(days=7)<=checked]
    if len(complete)<104: raise ValueError('need 104 complete weeks')
    previous,latest=complete[-104:-52],complete[-52:]
    block=lambda r:dict(start=r[0][0].isoformat(),end=r[-1][0].isoformat(),weeks=len(r),mean=round(statistics.mean(v for _,v in r),2))
    return dict(previous52=block(previous),latest52=block(latest),excludedIncomplete=[d.isoformat() for d,_ in parsed if d+dt.timedelta(days=7)>checked])
def main():
    result={'checkedOn':str(CHECKED),'method':'Separate normalized series, unweighted weekly means, 52 complete weeks against preceding 52; exclude any week not fully elapsed. Not absolute search volume, adoption or employment.','series':{}}
    for key in ['go-topic','golang']:
        data=json.loads((ROOT/f'trends-{key}-ui-tables.json').read_text())
        rows=data['tables'][0]
        result['series'][key]=summarize(rows)
        with (ROOT/f'trends-{key}.csv').open('w') as f:
            writer=csv.writer(f);writer.writerow(['week_start','normalized_interest'])
            for date,value in rows[1:]:writer.writerow([dt.datetime.strptime(re.sub('[\u202a-\u202e]','',date),'%b %d, %Y').date(),value])
    (ROOT/'trends-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2))
if __name__=='__main__':main()
