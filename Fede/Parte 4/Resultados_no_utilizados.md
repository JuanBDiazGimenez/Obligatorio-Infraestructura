# Resultados que recibimos pero no utilizamos

`Ejecutar` y `Recibir` son funciones que devuelven texto. Ada exige recoger ese resultado cuando las llamamos. Algunas llamadas se hacen por su efecto: enviar un mensaje mediante `RPUSH`, borrar claves mediante `DEL`, publicar la señal de arranque mediante `SET` o esperar y retirar un permiso con `Recibir`.

Al quitar los diagnósticos adicionales ya no necesitamos examinar esas cuatro respuestas, pero sí ejecutar las funciones. Por eso guardamos el resultado en una constante sin leerla después. La llamada a `Recibir` sigue esperando el permiso: no se elimina ni se adelanta la entrada del barco.

## Configuración elegida

En ambos comandos de compilación del Dockerfile se usa:

```text
-gnatwa -gnatwU -gnatwe
```

`-gnatwa` activa avisos generales; `-gnatwU` desactiva la categoría de elementos declarados pero no utilizados; `-gnatwe` trata los avisos restantes como errores. Se conserva también `-gnato`, que comprueba desbordamientos aritméticos.

Esta opción evita introducir lecturas artificiales con condiciones que no hacen nada. No modifica el comportamiento de los programas ni desactiva las comprobaciones de límites. Su alcance es más amplio que estas cuatro constantes: también oculta avisos sobre otras variables, parámetros o paquetes no utilizados en los archivos compilados con ella.

## Verificación y consulta pendiente

Se compilaron copias sin lecturas artificiales, con todos los avisos activos y sin convertirlos en errores: solo aparecieron las tres constantes de respuestas RPUSH/DEL/SET y la constante del permiso. Luego se comprobó la compilación con `-gnatwU` y el resto de los avisos tratados como errores. La imagen y la simulación completa también se verificaron con esa configuración.

Se acordó usar esta opción y consultar al profesor si este criterio es adecuado para la entrega. No se presenta como una configuración enseñada en clase.

Referencia externa: [Manual de GNAT, control de avisos](https://gcc.gnu.org/onlinedocs/gcc-13.4.0/gnat_ugn/Warning-Message-Control.html).
