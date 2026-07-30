// Qiita 記事「CPS 変換から継続モナドへ」のジェネレーター実装（動作確認用）
class Cont {
    constructor(runCont) { this.runCont = runCont; }
    static ret(x) { return new Cont(k => k(x)); }
    bind(k) { return new Cont(c => this.runCont(x => k(x).runCont(c))); }
    evalCont() { return this.runCont(x => x); }
}

function callCC(f) {
    return new Cont(c => f(x => new Cont(_ => c(x))).runCont(c));
}

function g() {
    return { value: undefined, next: () => callCC(ccOut => {
        function yield(value) {
            return callCC(next => ccOut({value, next}));
        }
        return (
            yield(1).bind(_ =>
            yield(2).bind(_ =>
            yield(3).bind(_ =>
            Cont.ret()
        ))));
    })};
}

let it = g();
while (it = it.next().evalCont()) {
    console.log(it.value);
}
