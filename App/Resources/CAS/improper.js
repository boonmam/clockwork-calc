// Original Clockwork Calc real improper-integral analysis. MIT, copyright 2026 boonmam.
// Only explicit analytic rules establish convergence. Unsupported rules return unresolved.
(function(scope){
'use strict';
const unresolved=message=>{throw Error('Convergence unresolved: '+message);};
function parse(source){
    const tokens=source.match(/(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?|[A-Za-z_][A-Za-z_0-9]*|[^\s]/g)||[];
    let i=0,depth=0;
    function expr(min=0){
        if(++depth>48)unresolved('expression nesting is too deep.');
        let token=tokens[i++],node;
        if(token==='-'||token==='+'){const a=expr(30);node=token==='-'?{op:'neg',a,src:'-('+a.src+')'}:a;}
        else if(token==='('){node=expr();if(tokens[i++]!==')')unresolved('cannot parse the integrand.');}
        else if(token&&/^(?:\d|\.)/.test(token))node={op:'constant',src:token};
        else if(token&&/^[A-Za-z_]/.test(token)){
            if(tokens[i]==='('){i++;let args=[expr()];while(tokens[i]===','){i++;args.push(expr());}if(tokens[i++]!==')')unresolved('cannot parse a function.');node={op:'call',name:token,args,src:token+'('+args.map(a=>a.src).join(',')+')'};}
            else node={op:'symbol',src:token};
        }else unresolved('unsupported integrand syntax.');
        while(i<tokens.length){
            const token=tokens[i], explicit={'+':10,'-':10,'*':20,'/':20,'^':40}[token];
            const implicit=explicit===undefined&&(token==='('||/^[A-Za-z_]/.test(token));
            const precedence=explicit??(implicit?20:undefined);
            if(precedence===undefined||precedence<min)break;
            const op=implicit?'*':tokens[i++],b=expr(precedence+(op==='^'?0:1));
            node={op,a:node,b,src:'('+node.src+op+b.src+')'};
        }
        depth--;return node;
    }
    const result=expr();if(i!==tokens.length)unresolved('unsupported integrand syntax.');return result;
}
function analyze(n,source,variable,lower,upper){
    const zero=n('0'),one=n('1');
    const finite=value=>({kind:'finite',value});
    const infinity=sign=>({kind:'infinite',sign});
    function numeric(value){
        const result=n.numeric(value),x=Number(result.text());
        if(!Number.isFinite(x)||result.variables().length)unresolved('a real finite constant is required.');
        if(x===0&&!n(value.text()).isZero())unresolved('a constant is too small for reliable interval ordering.');
        return x;
    }
    function bound(text){
        const cleaned=text.trim();
        if(/^\+?(?:inf|infinity)$/i.test(cleaned))return {text:'Infinity',number:Infinity};
        if(/^-(?:inf|infinity)$/i.test(cleaned))return {text:'-Infinity',number:-Infinity};
        const value=n(cleaned);return {text:value.text(),number:numeric(value)};
    }
    const originalA=bound(lower),originalB=bound(upper);
    if(originalA.number===originalB.number){
        if(!Number.isFinite(originalA.number))unresolved('equal infinite bounds do not define an interval.');
        return null;
    }
    const reversed=originalA.number>originalB.number;
    const a=reversed?originalB:originalA,b=reversed?originalA:originalB;
    const ast=parse(source),points=[],conditions=[];
    const calc=(op,x,y)=>n('('+x.text()+')'+op+'('+y.text()+')');
    function polynomial(node){
        if(node.op==='symbol'&&node.src===variable)return [zero,one];
        if(!n(node.src).variables().includes(variable))return [n(node.src)];
        if(node.op==='neg')return polynomial(node.a).map(c=>c.neg());
        if(node.op==='+'||node.op==='-'){
            const x=polynomial(node.a),y=polynomial(node.b),r=[];
            for(let i=0;i<Math.max(x.length,y.length);i++)r.push(calc(node.op,x[i]||zero,y[i]||zero));return trim(r);
        }
        function multiply(x,y){
            if(x.length+y.length>18)unresolved('polynomial analysis exceeds degree 16.');
            const r=Array(x.length+y.length-1).fill(zero);
            for(let i=0;i<x.length;i++)for(let j=0;j<y.length;j++)r[i+j]=calc('+',r[i+j],calc('*',x[i],y[j]));return trim(r);
        }
        if(node.op==='*')return multiply(polynomial(node.a),polynomial(node.b));
        if(node.op==='/'){
            const d=polynomial(node.b);if(d.length!==1||d[0].isZero())unresolved('non-polynomial singularity locations.');
            return polynomial(node.a).map(c=>calc('/',c,d[0]));
        }
        if(node.op==='^'){
            const p=numeric(n(node.b.src));if(!Number.isInteger(p)||p<0||p>16)unresolved('non-polynomial singularity locations.');
            let r=[one],base=polynomial(node.a);for(let j=0;j<p;j++)r=multiply(r,base);return r;
        }
        unresolved('cannot certify all singularity locations for '+node.src+'.');
    }
    function trim(p){while(p.length>1&&p[p.length-1].isZero())p.pop();return p;}
    function roots(node){
        const p=trim(polynomial(node));
        p.forEach(numeric);
        if(p.length===1){if(p[0].isZero())unresolved('the integrand is undefined throughout an interval.');return [];}
        if(p.length===2)return [calc('/',p[0].neg(),p[1])];
        if(p.length>3&&numeric(p[0])>0&&p.every((c,i)=>i%2?c.isZero():numeric(c)>=0))return [];
        if(p.length!==3)unresolved('singularity detection currently supports linear and quadratic factors and positive even polynomials.');
        const disc=calc('-',calc('*',p[1],p[1]),calc('*',n('4'),calc('*',p[2],p[0]))),d=numeric(disc);
        if(d<0)return [];
        const r=n('sqrt('+disc.text()+')'),den=calc('*',n('2'),p[2]);
        return d===0?[calc('/',p[1].neg(),den)]:[calc('/',calc('+',p[1].neg(),r),den),calc('/',calc('-',p[1].neg(),r),den)];
    }
    function restrict(node,kind){
        // Factor products/powers to certify all zeros without a heuristic root finder.
        function collect(node){
            if(node.op==='*'){collect(node.a);collect(node.b);return;}
            if(node.op==='^'&&numeric(n(node.b.src))>0){collect(node.a);return;}
            if(node.op==='call'&&['abs','sqrt'].includes(node.name)){collect(node.args[0]);return;}
            for(const r of roots(node)){
                const x=numeric(r);
                for(const edge of [a,b])if(x===edge.number&&Number.isFinite(x)&&!calc('-',r,n(edge.text)).isZero())unresolved('a singularity is too close to a bound to order reliably.');
                if(x>=a.number&&x<=b.number)points.push({text:r.text(),number:x});
            }
        }
        collect(node);conditions.push({node,kind});
    }
    function domain(node){
        if(node.op==='constant'||node.op==='symbol')return;
        if(node.op==='neg'){domain(node.a);return;}
        if(node.op==='call'){
            if(node.args.length!==1)unresolved('unsupported real-domain analysis for '+node.name+'.');
            const arg=node.args[0];domain(arg);
            if(['log','ln'].includes(node.name))restrict(arg,'positive');
            else if(node.name==='sqrt')restrict(arg,'nonnegative');
            else if(node.name==='abs')restrict(arg,'any');
            else if(!['exp','sin','cos','atan','abs','sinh','cosh','tanh'].includes(node.name))unresolved('real-domain analysis does not cover '+node.name+'.');
            return;
        }
        domain(node.a);domain(node.b);
        if(node.op==='/')restrict(node.b,'nonzero');
        if(node.op==='^'){
            const exponent=n(node.b.src);
            if(exponent.variables().includes(variable)){
                // A positive constant base is continuous for real exponents.
                if(n(node.a.src).variables().includes(variable)||numeric(n(node.a.src))<=0)unresolved('variable-power domain.');
            }else{
                const p=numeric(exponent);
                if(!Number.isInteger(p))restrict(node.a,p<0?'positive':'nonnegative');
                else if(p<0)restrict(node.a,'nonzero');
            }
        }
    }
    domain(ast);
    const unique=new Map();for(const p of points){
        const previous=unique.get(p.number);
        if(previous&&!calc('-',n(previous.text),n(p.text)).isZero())unresolved('singularities are too close to order reliably.');
        unique.set(p.number,p);
    }
    const interior=[...unique.values()].filter(p=>p.number>a.number&&p.number<b.number).sort((x,y)=>x.number-y.number);
    const cuts=[a,...interior,b];
    function midpoint(left,right){
        if(left===-Infinity&&right===Infinity)return 0;
        if(left===-Infinity)return right-Math.max(1,Math.abs(right));
        if(right===Infinity)return left+Math.max(1,Math.abs(left));
        return left/2+right/2;
    }
    for(let i=0;i<cuts.length-1;i++){
        const x=midpoint(cuts[i].number,cuts[i+1].number);
        if(!Number.isFinite(x)||x===cuts[i].number||x===cuts[i+1].number)unresolved('interval endpoints are too close or too large.');
        for(const {node,kind} of conditions){
            const value=numeric(n.subst(n(node.src),variable,n(String(x))));
            if((kind==='positive'&&value<=0)||(kind==='nonnegative'&&value<0)||(kind==='nonzero'&&value===0))
                throw Error('Real integral undefined: the integrand is not real and defined throughout this interval.');
        }
    }
    const isImproper=!Number.isFinite(a.number)||!Number.isFinite(b.number)||points.length>0;
    if(!isImproper)return null;
    function componentSource(node,at){
        if(node.op==='call'){
            const args=node.args.map(arg=>componentSource(arg,at));
            if(node.name==='abs'){
                const sample=numeric(n.subst(n(args[0]),variable,n(String(at))));
                return sample<0?'-( '+args[0]+' )':args[0];
            }
            return node.name+'('+args.join(',')+')';
        }
        if(node.op==='neg')return '-('+componentSource(node.a,at)+')';
        if(node.a&&node.b)return '('+componentSource(node.a,at)+node.op+componentSource(node.b,at)+')';
        return node.src;
    }
    function primitiveFor(expression){
        let anti=n.integrate(expression,variable);
        if(/\bintegrate\(/.test(anti.text())){
            // Exact integration-by-parts formula for P(x) exp(a*x+b), including a=-1.
            const node=parse(n(expression).text()),factors=[];
            function flatten(p){if(p.op==='*'){flatten(p.a);flatten(p.b);}else factors.push(p);}
            flatten(node);
            const index=factors.findIndex(p=>p.op==='^'&&p.a.src==='e'||p.op==='call'&&p.name==='exp');
            if(index>=0){
                const exponential=factors[index],arg=exponential.op==='^'?exponential.b:exponential.args[0];
                try{
                    const affine=polynomial(arg);
                    if(affine.length!==2)unresolved('exponential exponent is not affine.');
                    const other=factors.filter((_,i)=>i!==index),poly=n(other.length?other.map(p=>p.src).join('*'):'1');
                    const coefficients=polynomial(parse(poly.text())),slope=affine[1];
                    let term=poly,sum=zero;
                    for(let k=0;k<coefficients.length;k++){
                        let contribution=calc('/',term,n('('+slope.text()+')^'+(k+1)));
                        if(k%2)contribution=contribution.neg();sum=calc('+',sum,contribution);term=n.diff(term,variable);
                    }
                    anti=calc('*',sum,n(exponential.src));
                }catch(_) { /* Keep the unresolved integral when the exact rule does not apply. */ }
            }
        }
        if(/\bintegrate\(/.test(anti.text()))unresolved('no symbolic antiderivative was found; no numerical tail guess was used.');
        const residual=n.simplify(n.diff(anti,variable).minus(n(expression)));
        if(!residual.isZero())unresolved('the antiderivative could not be verified by differentiation.');
        return parse(anti.text());
    }
    function negate(x){return x.kind==='finite'?finite(x.value.neg()):infinity(-x.sign);}
    function sign(x){return Math.sign(numeric(x));}
    function nearSign(node,endpoint,direction){
        const p=trim(polynomial(node));
        if(!Number.isFinite(endpoint.number))return sign(p[p.length-1])*(endpoint.number<0&&(p.length-1)%2?-1:1);
        let expression=n(node.src);
        for(let k=0;k<p.length;k++){
            const v=n(n.subst(expression,variable,n(endpoint.text)).text());
            if(!v.isZero())return sign(v)*(direction==='left'&&k%2?-1:1);
            expression=n.diff(expression,variable);
        }
        unresolved('cannot determine an endpoint sign.');
    }
    function limit(node,endpoint,direction){
        if(!n(node.src).variables().includes(variable))return finite(n(node.src));
        if(node.op==='symbol'&&node.src===variable)return Number.isFinite(endpoint.number)?finite(n(endpoint.text)):infinity(Math.sign(endpoint.number));
        if(node.op==='neg')return negate(limit(node.a,endpoint,direction));
        if(node.op==='call'){
            if(node.args.length!==1)unresolved('unsupported primitive function.');
            const x=limit(node.args[0],endpoint,direction);
            switch(node.name){
            case 'log': case 'ln':
                // log|g| is the real primitive of g'/g on each zero-free real component.
                if(x.kind==='infinite')return infinity(1);
                if(x.value.isZero())return infinity(-1);
                return finite(n('log(abs('+x.value.text()+'))'));
            case 'sqrt':return power(x,finite(n('1/2')),node.args[0],endpoint,direction);
            case 'exp':return power(finite(n('e')),x,node.args[0],endpoint,direction);
            case 'atan':
                return x.kind==='infinite'?finite(n((x.sign<0?'-':'')+'pi/2')):finite(n('atan('+x.value.text()+')'));
            case 'abs':return x.kind==='infinite'?infinity(1):finite(n('abs('+x.value.text()+')'));
            case 'sin':case 'cos':
                if(x.kind==='infinite')unresolved('an oscillatory endpoint limit has not been established.');
                return finite(n(node.name+'('+x.value.text()+')'));
            default:unresolved('no certified endpoint rule for '+node.name+'.');
            }
        }
        if(!node.a||!node.b)unresolved('unsupported endpoint expression.');
        // Rational functions at infinity: compare polynomial degrees and leading coefficients.
        if(node.op==='/'&&!Number.isFinite(endpoint.number)){
            try{
                const p=trim(polynomial(node.a)),q=trim(polynomial(node.b)),degree=p.length-q.length;
                if(q.every(c=>c.isZero()))unresolved('zero denominator.');
                const ratio=calc('/',p[p.length-1],q[q.length-1]);
                if(degree<0)return finite(zero);
                if(degree===0)return finite(ratio);
                return infinity(sign(ratio)*(endpoint.number<0&&degree%2?-1:1));
            }catch(_) { /* Try the elementary rules; failure stays unresolved. */ }
        }
        const x=limit(node.a,endpoint,direction),y=limit(node.b,endpoint,direction);
        if(node.op==='^')return power(x,y,node.a,endpoint,direction);
        if(node.op==='+'||node.op==='-'){
            const z=node.op==='-'?negate(y):y;
            if(x.kind==='finite'&&z.kind==='finite')return finite(calc('+',x.value,z.value));
            if(x.kind==='infinite'&&z.kind==='infinite'&&x.sign!==z.sign)unresolved('indeterminate infinity minus infinity.');
            return x.kind==='infinite'?x:z;
        }
        if(node.op==='*'){
            if(x.kind==='finite'&&y.kind==='finite')return finite(calc('*',x.value,y.value));
            const sx=x.kind==='infinite'?x.sign:sign(x.value),sy=y.kind==='infinite'?y.sign:sign(y.value);
            if(!sx||!sy){
                const vanishing=!sx?node.a:node.b,growing=!sx?node.b:node.a;
                // A positive-order polynomial zero dominates a logarithmic singularity.
                if(Number.isFinite(endpoint.number)&&growing.op==='call'&&['log','ln'].includes(growing.name)){
                    try{
                        const z=polynomial(vanishing),g=polynomial(growing.args[0]);
                        if(z.length>1&&g.length>1&&n(n.subst(n(vanishing.src),variable,n(endpoint.text)).text()).isZero())return finite(zero);
                    }catch(_) { /* Unsupported order; leave unresolved. */ }
                }
                // Exponential decay with a nonconstant polynomial exponent dominates a polynomial.
                if(!Number.isFinite(endpoint.number)){
                    try{
                        polynomial(growing);
                        const arg=vanishing.op==='^'&&vanishing.a.src==='e'?vanishing.b:vanishing.op==='call'&&vanishing.name==='exp'?vanishing.args[0]:null;
                        if(arg&&polynomial(arg).length>1)return finite(zero);
                    }catch(_) { /* Unsupported growth comparison. */ }
                }
                unresolved('indeterminate zero times infinity.');
            }
            return infinity(sx*sy);
        }
        if(node.op==='/'){
            if(y.kind==='finite'&&y.value.isZero()){
                if(x.kind==='finite'&&x.value.isZero())unresolved('indeterminate zero divided by zero.');
                return infinity((x.kind==='infinite'?x.sign:sign(x.value))*nearSign(node.b,endpoint,direction));
            }
            if(y.kind==='infinite'){
                if(x.kind==='infinite')unresolved('indeterminate infinity divided by infinity.');
                return finite(zero);
            }
            return x.kind==='infinite'?infinity(x.sign*sign(y.value)):finite(calc('/',x.value,y.value));
        }
        unresolved('unsupported limit rule.');
    }
    function power(base,exponent,baseNode,endpoint,direction){
        if(exponent.kind==='infinite'){
            if(base.kind!=='finite')unresolved('indeterminate variable power.');
            const b=numeric(base.value);
            if(b<=0||b===1)unresolved('indeterminate exponential limit.');
            return Math.sign(Math.log(b))*exponent.sign<0?finite(zero):infinity(1);
        }
        const p=numeric(exponent.value);
        if(p===0)return finite(one);
        if(base.kind==='infinite'){
            if(base.sign<0&&!Number.isInteger(p))unresolved('complex power at infinity.');
            return p<0?finite(zero):infinity(base.sign<0&&Math.abs(p)%2?-1:1);
        }
        if(base.value.isZero()){
            if(p>0)return finite(zero);
            const s=nearSign(baseNode,endpoint,direction);
            if(s<0&&!Number.isInteger(p))unresolved('complex endpoint power.');
            return infinity(s<0&&Math.abs(p)%2?-1:1);
        }
        return finite(calc('^',base.value,exponent.value));
    }
    let total=zero;
    for(let i=0;i<cuts.length-1;i++){
        const local=componentSource(ast,midpoint(cuts[i].number,cuts[i+1].number));
        const primitive=primitiveFor(local);
        const lo=limit(primitive,cuts[i],'right'),hi=limit(primitive,cuts[i+1],'left');
        // Each tail and each side at every interior singularity must converge independently.
        if(lo.kind==='infinite'||hi.kind==='infinite')throw Error('Divergent improper integral: a one-sided antiderivative limit is infinite. Opposing infinities are not cancelled (no principal-value interpretation).');
        const part=calc('-',hi.value,lo.value);numeric(part);total=calc('+',total,part);
    }
    if(reversed)total=total.neg();
    return {value:total,approximate:total.hasDecimal(),warnings:[
        'Convergent improper integral.',
        'Verified antiderivative and separate one-sided endpoint limits.',
        interior.length?'Split at '+interior.map(p=>p.text).join(', ')+'. Every component converges independently; no principal value was used.':'Infinite bounds and singular endpoints were evaluated with limits, not finite cutoffs.'
    ]};
}
scope.FractionImproper={analyze};
if(typeof module!=='undefined')module.exports=scope.FractionImproper;
})(typeof self!=='undefined'?self:globalThis);
