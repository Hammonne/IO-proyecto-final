include("base.jl")
function geo(ins)
    J=num_maquinas(ins); o=1; f=pos_f(ins)
    @printf("K=%d C=%d n=%d J=%d  tau(f,o)=%.0f tau(o,f)=%.0f\n",ins.K,ins.C,num_lotes(ins),J,ins.tau[f,o],ins.tau[o,f])
    println(" j  o>a  a>b  b>f  b>o  f>a  f>b  o>b | tipos:tasa")
    for j in 1:J
        a,b=2j,2j+1
        @printf("%2d %4.0f %4.0f %4.0f %4.0f %4.0f %4.0f %4.0f | %s\n",j,ins.tau[o,a],ins.tau[a,b],ins.tau[b,f],ins.tau[b,o],ins.tau[f,a],ins.tau[f,b],ins.tau[o,b], join(["$r:$(round(ins.v[j,r],digits=2))" for r in 1:size(ins.v,2) if ins.v[j,r]>0]," "))
    end
    println("lotes por tipo: ",[count(==(r),ins.r) for r in 1:size(ins.v,2)], "  q medio por tipo: ",[round(sum(ins.q[ins.r.==r])/max(1,count(==(r),ins.r))) for r in 1:size(ins.v,2)])
end
function analiza(id)
    ins,seq,plan=cargar(id); e,ok=decodificar(ins,seq,plan); n=num_lotes(ins)
    println("\n===== $id valor=",round(sum(e.c)/n,digits=2)," ok=$ok")
    geo(ins)
    # tramos de AGV
    tot=Dict{String,Float64}(); cnt=Dict{String,Int}(); carg=0.0; vac=0.0; esp=0.0; fin_agv=Float64[]
    for a in 1:ins.K
        ops=filter(o->o.agv==a,e.ops); pos=1; t=0.0; carga=0
        for op in ops
            d=ins.tau[pos,op.lugar]
            if op.lugar!=pos
                key=nombre(ins,pos)*">"*nombre(ins,op.lugar)*(carga>0 ? "*" : "")
                tot[key]=get(tot,key,0.0)+d; cnt[key]=get(cnt,key,0)+1
                carga>0 ? (carg+=d) : (vac+=d)
            end
            esp+=op.tiempo-t-(op.lugar!=pos ? d : 0.0)
            t=op.tiempo; pos=op.lugar; carga+= op.tipo==:carga ? 1 : -1
        end
        push!(fin_agv,t)
    end
    T=sum(fin_agv)
    @printf("AGV: total=%.0f (fin por AGV %s) cargado=%.1f%% vacio=%.1f%% espera=%.1f%%  s/lote=%.1f\n",T,string(round.(fin_agv)),100carg/T,100vac/T,100esp/T,T/n)
    for (k,v) in sort(collect(tot),by=x->-x[2]); @printf("   %-6s n=%4d  t=%7.0f (%.1f%%) medio=%.1f\n",k,cnt[k],v,100v/T,v/cnt[k]); end
    # viajes
    nv=sum(length,plan); np=[count(es_real,v) for vs in plan for v in vs]
    ab=[count(p->es_real(p)&&p.abastece,v) for vs in plan for v in vs]; re=[count(p->es_real(p)&&!p.abastece,v) for vs in plan for v in vs]
    println("viajes=$nv  paradas/viaje: ",[count(==(k),np) for k in 1:maximum(np)],"  (abast,retir) frecuencia: ",sort(collect(pairs(Dict(k=>count(==(k),collect(zip(ab,re))) for k in unique(collect(zip(ab,re)))))),by=x->-x[2])[1:min(8,end)])
    println("visitas o: ",sum(count(visita_o,v) for vs in plan for v in vs)," visitas f: ",sum(count(visita_f,v) for vs in plan for v in vs))
    # máquinas
    println(" j  n  proc  esperaAbast bloqueo  finUlt  s_AGV_ruta")
    te=0.0;tb=0.0
    for j in 1:num_maquinas(ins)
        isempty(seq[j]) && (println(@sprintf("%2d  0",j)); continue)
        proc=sum(tiempo_proceso(ins,i,j) for i in seq[j]); ea=0.0; bl=0.0
        for k in eachindex(seq[j])
            prev = k==1 ? 0.0 : e.salida[j][k-1]
            ea+=max(0,e.llegada[j][k]-prev); bl+=e.salida[j][k]-e.fin[j][k]
        end
        te+=ea;tb+=bl
        @printf("%2d %3d %6.0f %8.0f %7.0f %7.0f %5.0f\n",j,length(seq[j]),proc,ea,bl,e.salida[j][end],ruta_lote(ins,j))
    end
    @printf("espera abastecimiento total=%.0f bloqueo total=%.0f\n",te,tb)
    # descomposición por lote
    ubic=ubicar_lotes(seq); w1=0.0;w2=0.0;w3=0.0
    for i in 1:n; j,k=ubic[i]; w1+=e.inicio[j][k]; w2+=e.recojo[j][k]-e.fin[j][k]; w3+=e.c[i]-e.recojo[j][k]; end
    pm=sum(tiempo_proceso(ins,i,ubic[i][1]) for i in 1:n)/n
    @printf("por lote: inicio medio=%.1f proc=%.1f espera recojo=%.1f a bordo hasta f=%.1f (directo b>f medio=%.1f)\n",w1/n,pm,w2/n,w3/n,sum(ins.tau[pos_beta(ins,ubic[i][1]),pos_f(ins)] for i in 1:n)/n)
    cs=sort(e.c); println("cuantiles de c: ",round.(cs[[1,n÷10,n÷4,n÷2,3n÷4,9n÷10,n]]))
    @printf("makespan=%.0f; si salieran a ritmo uniforme desde c1: media=%.1f\n",cs[end],(cs[1]+cs[end])/2)
end
foreach(analiza,ARGS)
