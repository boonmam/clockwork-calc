// Original Clockwork Calc adapter, Copyright 2026 boonmam, MIT.
// The input is mathematical notation passed to Nerdamer's parser, never JavaScript eval.
(function (scope) {
    'use strict';
    const allowed = new Set(('simplify expand factor diff integrate limit solve subst numeric sqrt sin cos tan asin acos atan sinh cosh tanh exp log log10 abs floor ceil determinant invert transpose rref matrix imatrix vector dot cross gcd lcm partfrac coeffs nint linsolve rank').split(' '));
    const aliases = {ln:'log', det:'determinant', inv:'invert', integral:'integrate'};
    function splitArguments(text) {
        let depth=0, start=0, result=[];
        for (let i=0;i<text.length;i++) {
            if ('([{'.includes(text[i])) depth++;
            if (')]}'.includes(text[i])) depth--;
            if (text[i]===',' && depth===0) { result.push(text.slice(start,i).trim()); start=i+1; }
        }
        result.push(text.slice(start).trim()); return result;
    }
    function topCall(input) {
        const match=/^([A-Za-z]+)\((.*)\)$/s.exec(input);
        if (!match) return null;
        let depth=0;
        for(let i=input.indexOf('(');i<input.length-1;i++) { if(input[i]==='(')depth++; if(input[i]===')')depth--; if(depth===0)return null; }
        return {name:match[1], args:splitArguments(match[2])};
    }
    function validate(raw) {
        let input=raw.replace(/∞/g,'Infinity').replace(/π/g,'pi').replace(/×/g,'*').replace(/÷/g,'/').replace(/−/g,'-').trim();
        if (!input || input.length>4096) throw Error('CAS expressions must contain 1–4096 characters.');
        if (/[^A-Za-z0-9_+*/^().,=\[\]{}\s-]/.test(input)) throw Error('Use mathematical expressions, not scripts or assignments.');
        if (/__|\b(?:while|for|if|function|eval|import|constructor|prototype)\b/.test(input)) throw Error('Scripting is not supported.');
        const tokens=input.match(/[A-Za-z_][A-Za-z_0-9]*|\d+(?:\.\d*)?(?:[eE][+-]?\d+)?|[^\s]/g)||[];
        if(tokens.length>512)throw Error('CAS expressions are limited to 512 tokens.');
        let stack=[];
        for(const c of input){ if('([{'.includes(c)){stack.push(c);if(stack.length>32)throw Error('CAS nesting exceeds 32 levels.');}
            if(')]}'.includes(c) && stack.pop() !== ({')':'(',']':'[','}':'{'})[c])throw Error('Mismatched brackets.'); }
        if(stack.length)throw Error('Mismatched brackets.');
        input=input.replace(/\b([A-Za-z_][A-Za-z_0-9]*)\s*\(/g,(match,name)=>{
            name=aliases[name]||name;
            if(!allowed.has(name))throw Error('Unsupported CAS function: '+name+'. Use * for multiplication.');
            return name+'(';
        });
        for(const match of input.matchAll(/\bimatrix\(([^)]*)\)/g)) {
            if(!/^[1-8]$/.test(match[1].trim()))throw Error('Identity matrices support sizes 1–8.');
        }
        if(/\d{129}/.test(input))throw Error('Numeric literals are limited to 128 digits.');
        // Restrict explicitly huge powers; the worker deadline also covers symbolic growth.
        for(const match of input.matchAll(/\^\s*\(?\s*([+-]?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?)/g)) {
            if(Math.abs(Number(match[1]))>1000)throw Error('Explicit powers are limited to magnitude 1000.');
        }
        return input;
    }
    function realNumber(n, expression) {
        const result=n.numeric(expression);
        if (result.dataType!=='EXP' || (result.variables && result.variables().length)) throw Error('A real numeric value is required.');
        const value=Number(result.text());
        if(!Number.isFinite(value))throw Error('A finite real numeric value is required.');
        return value;
    }
    function integral(n, args, numerical) {
        if(args.length!==4)throw Error('Use integrate(f,x,a,b) or nint(f,x,a,b).');
        const [source,variable,lower,upper]=args;
        if(!/^[A-Za-z][A-Za-z0-9_]*$/.test(variable) || ['pi','e','i'].includes(variable))throw Error('Choose a plain integration variable, such as x.');
        const improper=scope.FractionImproper || (typeof require==='function'?require('./improper.js'):null);
        if(!improper)throw Error('Improper integral analysis is unavailable.');
        let analysis;
        try { analysis=improper.analyze(n,source,variable,lower,upper); }
        catch(error) {
            if(/^(Convergence unresolved:|Divergent improper integral:|Real integral undefined:)/.test(error.message))throw error;
            throw Error('Convergence unresolved: the symbolic analysis could not complete ('+error.message+').');
        }
        if(analysis) {
            if(numerical){analysis.value=n.numeric(analysis.value);analysis.approximate=true;}
            return analysis;
        }
        const f=n(source), a=realNumber(n,n(lower)), b=realNumber(n,n(upper));
        if(f.dataType!=='EXP' || f.variables().some(x=>x!==variable))throw Error('Definite integration requires a scalar with only its integration variable.');
        if(a===b)return {value:n('0'),approximate:false,warnings:[]};
        const left=Math.min(a,b),right=Math.max(a,b);
        // Screen rational poles before quadrature; sampling alone can miss narrow singularities.
        const denominator=f.getDenominator();
        if(denominator.variables().includes(variable)) {
            const poles=n.solve(denominator,variable);
            if(poles.partial || poles.unsolved)throw Error('Cannot certify denominator roots for this interval.');
            for(const root of poles.elements||[]) {
                let x; try {x=realNumber(n,root);}catch(_){continue;}
                if(x>=left&&x<=right)throw Error('Convergence unresolved: an unclassified singularity remains in the interval.');
            }
        }
        // Compiled by the CAS from the validated math expression, not from user JavaScript.
        const fn=f.buildFunction([variable]);
        let samples=0;
        const at=x=>{if(++samples>50000)throw Error('Integration sample limit reached.');const y=Number(fn(x));if(!Number.isFinite(y))throw Error('Convergence unresolved: a nonfinite sample was not classified by the domain analysis.');return y;};
        for(let i=0;i<=64;i++)at(left+(right-left)*i/64);
        const simpson=(lo,hi,fa,fm,fb)=>(hi-lo)*(fa+4*fm+fb)/6;
        const fa=at(left),fb=at(right),mid=(left+right)/2,fm=at(mid),whole=simpson(left,right,fa,fm,fb);
        function adaptive(lo,hi,fa,fm,fb,estimate,tolerance,depth){
            const mid=(lo+hi)/2,fl=at((lo+mid)/2),fr=at((mid+hi)/2);
            const l=simpson(lo,mid,fa,fl,fm),r=simpson(mid,hi,fm,fr,fb),delta=l+r-estimate;
            if(Math.abs(delta)<=15*tolerance)return l+r+delta/15;
            if(depth===0)throw Error('Integral did not converge; check discontinuities or oscillation.');
            return adaptive(lo,mid,fa,fl,fm,l,tolerance/2,depth-1)+adaptive(mid,hi,fm,fr,fb,r,tolerance/2,depth-1);
        }
        // Begin with multiple non-dyadic panels to reduce false convergence from aliased oscillations.
        let estimate=0;
        const panels=17;
        for(let i=0;i<panels;i++) {
            const lo=left+(right-left)*i/panels, hi=left+(right-left)*(i+1)/panels, mid=(lo+hi)/2;
            const fa=at(lo),fm=at(mid),fb=at(hi);
            estimate+=adaptive(lo,hi,fa,fm,fb,simpson(lo,hi,fa,fm,fb),1e-9/panels,18);
        }
        estimate*=a>b?-1:1;
        if(!Number.isFinite(estimate))throw Error('Integral is outside the supported numeric range.');
        const warnings=['Finite continuous real intervals only; the numerical error estimate is not a proof of convergence.'];
        if(!numerical){
            const anti=n.integrate(f,variable);
            if(!/\bintegrate\(/.test(anti.text())) {
                const value=n(n.subst(anti,variable,n(upper)).minus(n.subst(anti,variable,n(lower))).text());
                const check=realNumber(n,value);
                if(Math.abs(check-estimate)<=1e-7*Math.max(1,Math.abs(estimate)))return {value,approximate:value.hasDecimal(),warnings};
                throw Error('Symbolic and numerical integrals disagree; check the interval domain.');
            }
            warnings.push('No symbolic antiderivative found; returned numerical quadrature.');
        }
        return {value:n(String(estimate)),approximate:true,warnings};
    }
    function hasApproximation(value) {
        if(Array.isArray(value))return value.some(hasApproximation);
        if(value.hasDecimal)return value.hasDecimal();
        return value.elements ? hasApproximation(value.elements) : false;
    }
    function mapNumeric(n, value) {
        if(value.dataType==='EXP')return n.numeric(value);
        if(value.isEnumerable)return value.copy().each(item=>mapNumeric(n,item));
        return value;
    }
    function evaluate(n, raw, exact) {
        const input=validate(raw),call=topCall(input);
        if(call?.name==='solve' && call.args[0]?.trim().startsWith('['))throw Error('Use linsolve([equations],[variables]) for linear systems.');
        let value, approximate=false, warnings=[];
        if(call && (call.name==='nint'||call.name==='integrate'&&call.args.length===4)) {
            ({value,approximate,warnings}=integral(n,call.args,call.name==='nint'));
        } else if(call && call.name==='linsolve') {
            if(call.args.length!==2 || !call.args.every(a=>a.startsWith('[')&&a.endsWith(']')))throw Error('Use linsolve([equations],[variables]).');
            const equations=splitArguments(call.args[0].slice(1,-1)),variables=splitArguments(call.args[1].slice(1,-1));
            if(equations.length>8||variables.length>8||!variables.every(v=>/^[A-Za-z][A-Za-z0-9_]*$/.test(v)))throw Error('Systems support up to eight equations and variables.');
            // Reject nonlinear systems rather than expose the library heuristic fallback as a linear solver.
            for(const source of equations) {
                const sides=source.split('='); if(sides.length>2)throw Error('Invalid equation.');
                const expr=n('('+sides[0]+')-('+ (sides[1]||'0') +')');
                for(const v of variables)if(n.diff(expr,v).variables().some(x=>variables.includes(x)))throw Error('linsolve requires linear equations.');
            }
            value=n.solveSystem(equations,variables);
            warnings.push('Solutions are shown as variable → value; solution dictionaries are not scalar inputs.');
        } else if(call && call.name==='rank') {
            if(call.args.length!==1)throw Error('rank requires one matrix.');
            const m=n('rref('+call.args[0]+')');if(m.dataType!=='MAT')throw Error('rank requires a matrix.');
            value=n(String(m.elements.filter(row=>row.some(x=>!x.isZero())).length));
        } else {
            if(/\b(?:nint|linsolve|rank)\(/.test(input))throw Error('nint, linsolve, and rank must be the outermost operation.');
            // A two-argument integrate is delegated to the symbolic integrator.
            value=n(input);
            if(call && call.name==='determinant')value=n.expand(value);
        }
        if(value.dataType==='MAT' && (value.elements.length>8 || value.elements.some(row=>row.length>8)))throw Error('Matrices are limited to 8 × 8.');
        if(/\b(?:invert|rref|rank|determinant)\(/.test(input))warnings.push('Symbolic matrix results assume valid nonzero pivots; check special parameter values.');
        if(value.partial||value.unsolved)warnings.push('The solver returned a partial or unresolved solution set; it may not contain every root.');
        if(/\bsolve\(/.test(input))warnings.push('General equation solving may be incomplete. Check candidate roots and the original domain.');
        if(/\bintegrate\(/.test(value.text()))warnings.push('This integral remains unevaluated: no closed form was found.');
        else if(call&&call.name==='integrate'&&call.args.length===2)warnings.push('An indefinite integral is one antiderivative; add an arbitrary constant C.');
        if(/\b(?:simplify|factor|diff)\(/.test(input))warnings.push('Symbolic transformations may change apparent domains; retain the original restrictions.');
        if(hasApproximation(value))approximate=true;
        if(!exact) { value=mapNumeric(n,value);approximate=true; }
        let text=value.text(),latex=n.convertToTeX(value,{decimal:approximate});
        if(value.dataType==='MAT')latex='\\left['+latex+'\\right]';
        if(text.length>20000 || latex.length>40000)throw Error('Result is too large to display.');
        let inputLatex;
        try {
            inputLatex=n.convertToTeX(input);
            if(call && ['integrate','nint'].includes(call.name) && call.args.length===4) {
                const boundTex=s=>/^[+]?inf(?:inity)?$/i.test(s)?'\\infty':/^-inf(?:inity)?$/i.test(s)?'-\\infty':n.convertToTeX(s);
                inputLatex='\\int_{'+boundTex(call.args[2])+'}^{'+boundTex(call.args[3])+'} '+n.convertToTeX(call.args[0])+'\\,d'+call.args[1];
            }
        } catch(_) {inputLatex='\\text{CAS calculation}';}
        return {text,latex,inputLatex,approximate,warnings};
    }
    scope.FractionCAS={evaluate,validate};
    if(typeof module!=='undefined')module.exports=scope.FractionCAS;
    else scope.onmessage=event=>{try{scope.postMessage({ok:true,...evaluate(scope.nerdamer,event.data.input,event.data.exact)});}catch(error){scope.postMessage({ok:false,error:String(error.message||error)});}};
})(typeof self!=='undefined'?self:globalThis);
