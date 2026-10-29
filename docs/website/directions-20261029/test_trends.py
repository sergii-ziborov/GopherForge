import datetime as dt, unittest
from analyze_trends import summarize
class TrendsTests(unittest.TestCase):
    def rows(self):
        start=dt.date(2024,10,27)
        return [['x','y1']]+[[(start+dt.timedelta(weeks=i)).strftime('%b %d, %Y'),str(10 if i<52 else 20)] for i in range(105)]
    def test_current_partial_week_excluded(self):
        s=summarize(self.rows());self.assertEqual(s['previous52']['mean'],10);self.assertEqual(s['latest52']['mean'],20);self.assertEqual(s['excludedIncomplete'],['2026-10-25'])
    def test_gap_is_not_silently_averaged(self):
        rows=self.rows();rows.pop(4)
        with self.assertRaises(ValueError):summarize(rows)
    def test_invalid_score_rejected(self):
        rows=self.rows();rows[1][1]='101'
        with self.assertRaises(ValueError):summarize(rows)
if __name__=='__main__':unittest.main()
