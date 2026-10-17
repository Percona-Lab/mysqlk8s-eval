import sys,re
# analyze_load.py load.log _ignored T_ms [end_ms] -> tps stats in window; handles restarts (START <epoch_ms>)
f,T=sys.argv[1],int(sys.argv[3]); E=int(sys.argv[4]) if len(sys.argv)>4 else 10**15
pts=[]; s0=None; restarts=0
for l in open(f):
    if l.startswith('START '): s0=int(l.split()[1]); 
    if l.startswith('EXIT ') and T<=int(l.split()[1])<=E: restarts+=1
    m=re.match(r'\[ *(\d+)s \] thds: \d+ tps: ([\d.]+).*err/s: ([\d.]+) reconn/s: ([\d.]+)',l)
    if m and s0:
        t=s0+int(m.group(1))*1000
        if T<=t<=E: pts.append((t,float(m.group(2)),float(m.group(3)),float(m.group(4))))
if not pts: print("LOAD no samples in window"); sys.exit()
base=sorted(p[1] for p in pts)[len(pts)//2]
gaps=sum(max(0,b[0]-a[0]-10000) for a,b in zip(pts,pts[1:]))/1000
low=[p for p in pts if p[1]<0.5*base]
print(f"LOAD samples={len(pts)} median_tps={base:.1f} min_tps={min(p[1] for p in pts):.1f} intervals_below_50pct={len(low)} sysbench_restarts={restarts} report_gaps={gaps:.0f}s max_err/s={max(p[2] for p in pts):.1f}")
