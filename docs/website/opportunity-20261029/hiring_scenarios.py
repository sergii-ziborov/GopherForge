"""Synthetic selection-bias example; these records are not Djinni candidates."""
import json,statistics

def scenario(other):
    rows=[{'hired':True,'applications':10} for _ in range(10)]+[{'hired':False,'applications':10} for _ in range(other)]
    hired=[r for r in rows if r['hired']]
    return {'hired':len(hired),'other':other,'hiredApplicationMedian':statistics.median(r['applications'] for r in hired),'observedSharePercent':100*len(hired)/len(rows)}
if __name__=='__main__':
    result={'syntheticNotPlatformData':True,'A':scenario(10),'B':scenario(190)}
    assert result['A']['hiredApplicationMedian']==result['B']['hiredApplicationMedian']==10
    assert result['A']['observedSharePercent']==50 and result['B']['observedSharePercent']==5
    print(json.dumps(result,indent=2))
