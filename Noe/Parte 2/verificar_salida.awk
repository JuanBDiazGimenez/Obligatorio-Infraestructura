# verifica propiedades pedidas a partir de la salida del programa
/generó paquete/   { id=$5; peso[id]=$8; g[id]++; ng++ }
/Escáner .* procesó/ { id=$5; e[id]++; ne++ }
/envió paquete/    { id=$5; c[id]++; nc++
                     if ($NF=="PRIORIDAD") { qp[++tp]=id; occp++; if (occp>10) bad("cola prio >10 en "id); if (peso[id]<=10) bad("prio con peso<=10 "id) }
                     else { qn[++tn]=id; occn++; if (occn>15) bad("cola normal >15 en "id); if (peso[id]>10) bad("normal con peso>10 "id) } }
/despachó paquete/ { id=$5; d[id]++; nd++
                     if (!(g[id]&&e[id]&&c[id])) bad("despachado sin pasar etapas "id)
                     if ($(NF)!=peso[id]*100) bad("costo mal "id)
                     if ($(NF-3)=="ALTA") { if (qp[++dp]!=id) bad("FIFO prio "id); occp--; run++
                                            if (run>3 && occn>0) bad("4to prioritario seguido con normal esperando "id) }
                     else                 { if (qn[++dn]!=id) bad("FIFO normal "id); occn--; run=0 } }
function bad(m){ print "ERROR:", m; err++ }
END { for(i=1;i<=300;i++) if (g[i]!=1||e[i]!=1||c[i]!=1||d[i]!=1) bad("paquete "i" repetido/perdido")
      if (ng!=300||ne!=300||nc!=300||nd!=300) bad("totales "ng" "ne" "nc" "nd)
      print err? "FALLO" : "OK: 300 paquetes, etapas, FIFO, capacidades, prioridad y regla de 3 consecutivos" }
