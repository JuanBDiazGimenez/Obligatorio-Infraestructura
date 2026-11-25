# Lectura de CSV con finales LF y CRLF

## Problema y corrección

El CSV proporcionado usa CRLF. El read de Bash conserva el retorno de carro en el último campo; antes, Si seguido de CR no coincidía con Si y podía impedir asignar un dron disponible o mostrar mal su estado.

Se corrigieron dos lugares de don_drones.sh: buscar_dron limpia DISP antes de devolver el registro y mostrar_dron limpia el argumento de disponibilidad antes de compararlo. Ambos utilizan `sed 's/\r$//'`, que elimina únicamente un retorno de carro final del valor leído. No convierte ni reescribe el archivo completo. Las altas, actualizaciones y asignaciones siguen persistiendo normalmente mediante las operaciones del programa.

sed ya estaba en el script original proporcionado; esta expresión para el retorno de carro es una adaptación propia, acordada con Fede, no un ejemplo atribuido al docente.

## Comprobación del 25/11/2026

Las pruebas en copias LF y CRLF pasaron tanto en Git Bash de Windows como en Ubuntu WSL: reporte, asignación de COO-003, rechazo de una nueva asignación, actualización, reasignación y persistencia. En Git Bash se comprobó además que leer y mostrar no altera los bytes del CSV. El CSV del repositorio quedó intacto.

La incompatibilidad anterior de disponibilidad queda resuelta para esos dos formatos. No hace falta convertir el CSV a LF como paso de prueba ni advertir que esta lectura exige LF. Esto no equivale a admitir cualquier formato CSV, codificación o archivo de usuarios externo. El propio script sigue preparado con finales LF.
