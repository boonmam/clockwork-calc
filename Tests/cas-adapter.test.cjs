// Node-only fast checks of the exact adapter shipped in the app. No npm install needed.
const assert=require('node:assert/strict');
const n=require('../App/Resources/CAS/nerdamer.js');
const cas=require('../App/Resources/CAS/adapter.js');
let count=0;
function evaluate(s,exact=true){return cas.evaluate(n,s,exact);}
function equal(s,want){assert.equal(evaluate(s).text,want,s);count++;}
function near(s,want){assert.ok(Math.abs(Number(evaluate(s).text)-want)<1e-8,s);count++;}
function rejects(s){assert.throws(()=>evaluate(s),undefined,s);count++;}
equal('x+x','2*x');
equal('expand((x+1)^3)','1+3*x+3*x^2+x^3');
equal('simplify((x^2-1)/(x-1))','1+x');
equal('expand(factor(x^2-1))','-1+x^2');
equal('subst(x^2+1,x,3)','10');
equal('limit(sin(x)/x,x,0)','1');
equal('diff(integrate(x^2,x),x)','x^2');
equal('simplify(diff(integrate(x^2*sin(x),x),x)-x^2*sin(x))','0');
equal('integrate(x^2,x,0,1)','1/3');
equal('integrate(x^2,x,1,0)','-1/3');
equal('integrate(sin(x),x,0,pi)','2');
near('nint(exp(-x^2),x,0,1)',0.7468241328124271);
near('nint(sin(128*pi*x)^2,x,0,1)',0.5);
assert.ok(evaluate('integrate(sin(x^x),x)').warnings.some(w=>w.includes('unevaluated')));count++;
equal('matrix([1,2],[3,4])+matrix([4,3],[2,1])','matrix([5, 5], [5, 5])');
equal('matrix([1,2],[3,4])^2','matrix([7, 10], [15, 22])');
equal('transpose(matrix([1,2,3],[4,5,6]))','matrix([1, 4], [2, 5], [3, 6])');
equal('invert(matrix([1,2],[3,4]))*matrix([1,2],[3,4])','matrix([1, 0], [0, 1])');
assert.equal(n('simplify(('+evaluate('det(matrix([a,b],[c,d]))').text+')-(a*d-b*c))').text(),'0');count++;
equal('rref(matrix([1,2,3],[2,4,6]))','matrix([1, 2, 3], [0, 0, 0])');
equal('rank(matrix([1,2],[2,4]))','1');
equal('linsolve([x+y=3,x-y=1],[x,y])','[{x => 2, y => 1}]');
assert.ok(evaluate('solve(x^3-1,x)').text.includes('3^(1/2)*i'));count++;
assert.ok(evaluate('matrix([1/3,pi])',false).approximate);count++;
assert.ok(evaluate('matrix([0.1,1])').approximate);count++;
for(const s of ['invert(matrix([1,2],[2,4]))','matrix([1,2],[3])','matrix([1,2])*matrix([1,2])',
 'integrate(1/x,x,-1,1)','nint(1/(x-0.1),x,-1,1)','nint(sqrt(x),x,-1,1)',
 'nint(tan(x),x,0,pi)','nint(x+y,x,0,1)','nint(x,x,0,infinity)','imatrix(9)',
 'imatrix(2+2)','2^1000000','unknown(x)','x:=1','while(1)','x; x','[1,2)',
 'linsolve([x^2=1],[x])','solve([x+y=3,x-y=1],[x,y])','fetch(x)'])rejects(s);
console.log(`${count} CAS adapter checks passed`);
