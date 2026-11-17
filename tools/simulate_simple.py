"""Checks the slopes and ocean/mountain shares of the simple pack without starting the game (numpy only).
Re-implements Minecraft Perlin/NormalNoise with random permutations, so numbers are statistical (the real seed differs).
Usage: python tools/simulate_simple.py"""
import os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np, math
from simple_terrain import terrain
import numpy as np, math
G=np.array([[1,1,0],[-1,1,0],[1,-1,0],[-1,-1,0],[1,0,1],[-1,0,1],[1,0,-1],[-1,0,-1],[0,1,1],[0,-1,1],[0,1,-1],[0,-1,-1],[1,1,0],[0,-1,1],[-1,1,0],[0,-1,-1]],float)
class Imp:
  def __init__(s,rng):
    s.o=rng.random(3)*256; s.p=rng.permutation(256)
  def __call__(s,x,y,z):
    x=x+s.o[0]; y=y+s.o[1]; z=z+s.o[2]
    xi=np.floor(x).astype(int); yi=np.floor(y).astype(int); zi=np.floor(z).astype(int)
    xf=x-xi; yf=y-yi; zf=z-zi
    P=lambda i: s.p[i&255]
    def g(h,dx,dy,dz): v=G[h&15]; return v[...,0]*dx+v[...,1]*dy+v[...,2]*dz
    fade=lambda t: t*t*t*(t*(t*6-15)+10)
    a=P(xi); aa=P(a+yi); ab=P(a+yi+1); b=P(xi+1); ba=P(b+yi); bb=P(b+yi+1)
    def h(q,c): return P(q+zi+c)
    u,v,w=fade(xf),fade(yf),fade(zf)
    L=lambda t,a_,b_: a_+t*(b_-a_)
    x1=L(u,g(h(aa,0),xf,yf,zf),g(h(ba,0),xf-1,yf,zf)); x2=L(u,g(h(ab,0),xf,yf-1,zf),g(h(bb,0),xf-1,yf-1,zf))
    y1=L(v,x1,x2)
    x1=L(u,g(h(aa,1),xf,yf,zf-1),g(h(ba,1),xf-1,yf,zf-1)); x2=L(u,g(h(ab,1),xf,yf-1,zf-1),g(h(bb,1),xf-1,yf-1,zf-1))
    y2=L(v,x1,x2); return L(w,y1,y2)
def perlin(rng,first,amps,x,z):
  n=len(amps); octs=[Imp(rng) for _ in amps]; tot=0
  lf=2.0**first; vf=2.0**(n-1)/(2.0**n-1)
  for i,(o,a) in enumerate(zip(octs,amps)):
    if a: tot=tot+a*vf*o(x*lf,0*x,z*lf)
    lf*=2; vf/=2
  return tot
def normal(rng,first,amps,x,z):
  idx=[i for i,a in enumerate(amps) if a]; span=max(idx)-min(idx)
  vf=(1/6)/(0.1*(1+1/(span+1)))
  f=1.0181268882175227
  return (perlin(rng,first,amps,x,z)+perlin(rng,first,amps,x*f,z*f))*vf
vals=[]
C_OCT = (-12, [1, 1, 2, 2, 2])
E_OCT = (-12, [1, 1, 1, 0.5, 0.5])
W_OCT = (-9, [1, 2, 1])
D_OCT = (-8, [1])
P_OCT = (-7, [1, 0.5])
EROSION_SHIFT = -0.1

def fields(rng, X, Z):
    c = normal(rng, *C_OCT, X * 0.25, Z * 0.25)
    e = normal(rng, *E_OCT, X * 0.25, Z * 0.25) + EROSION_SHIFT
    w = normal(rng, *W_OCT, X * 0.25, Z * 0.25)
    d = normal(rng, *D_OCT, X, Z)
    p = normal(rng, *P_OCT, X, Z)
    return c, e, w, d, p

if __name__ == '__main__':
    slopes = []; slopes2 = []; allc = []; alle = []; allh = []
    for seed in range(12):
        rng = np.random.default_rng(seed)
        # big area stats (coarse)
        X = rng.random(40000) * 400000 - 200000; Z = rng.random(40000) * 400000 - 200000
        st = np.random.get_state()
        rr = np.random.default_rng(seed)
        c, e, w, d, pk = fields(rng, X, Z)
        h = terrain(c, e, w, d, pk)
        allc.append(c); alle.append(e); allh.append(h)
        # transects: 1-block spacing, 3000 blocks long, in x and z; same noise instances => reuse rng state
    # transects need identical noise instances: build them once per seed
    for seed in range(12):
        rng = np.random.default_rng(100 + seed)
        n = 400
        x0 = rng.random(n) * 300000 - 150000; z0 = rng.random(n) * 300000 - 150000
        t = np.arange(0, 600)
        # noise instances are created inside normal() from rng, so evaluate both directions in a single call
        X = np.concatenate([x0[:, None] + t[None, :], np.repeat(x0[:, None], 600, 1)], 0)
        Z = np.concatenate([np.repeat(z0[:, None], 600, 1), z0[:, None] + t[None, :]], 0)
        c, e, w, d, pk = fields(rng, X, Z)
        h = terrain(c, e, w, d, pk)
        # slope over 1.5 blocks: use 2 block steps
        s = np.abs(h[:, 2:] - h[:, :-2]) / 2.0
        slopes.append(s.ravel())
        slopes2.append(np.abs(h[:, 4:] - h[:, :-4]).ravel() / 4.0)
    c = np.concatenate(allc); e = np.concatenate(alle); h = np.concatenate(allh)
    print('c std %.3f  e std %.3f' % (c.std(), e.std()))
    print('c<-0.455 (deep ocean) %.1f%%, ocean %.1f%%, land %.1f%%' % (100 * (c < -0.455).mean(), 100 * ((c >= -0.455) & (c < -0.19)).mean(), 100 * (c >= -0.19).mean()))
    print('mountain area (e<-0.45 & c>0.1): %.1f%%' % (100 * ((e < -0.45) & (c > 0.1)).mean()))
    print('height quantiles', np.round(np.quantile(h, [0, .01, .1, .25, .5, .75, .9, .99, .999, 1]), 1))
    s = np.concatenate(slopes)
    print('slope per block: mean %.3f  q99 %.3f  q99.9 %.3f  q99.99 %.3f  max %.3f' % (s.mean(), *np.quantile(s, [.99, .999, .9999]), s.max()))
    s2 = np.concatenate(slopes2)
    print('slope over 4 blocks: q99.9 %.3f max %.3f' % (np.quantile(s2, .999), s2.max()))
