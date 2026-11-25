# Entornos de ejecución y uso de IA

## Entornos utilizados

Las partes 1, 2 y 3 se probaron en Ubuntu dentro del contenedor Docker `mi_ubuntu`, utilizando Bash y los comandos del sistema para la parte 1, GCC con hilos y semáforos POSIX para la parte 2, y GNAT para compilar y ejecutar Ada en la parte 3.

También se probaron en Windows nativo con Git Bash para la parte 1 y MSYS2/UCRT64 para las partes 2 y 3, utilizando GCC con Winpthreads y GNAT, respectivamente.

**PENDIENTE: QUE UN INTEGRANTE DEL EQUIPO PRUEBE MANUALMENTE LAS PARTES 1, 2 Y 3 EN WINDOWS NATIVO.**

La parte 4 se probó con Docker Desktop en Windows, utilizando contenedores Linux y Docker Compose. Los programas Ada se compilan y ejecutan en imágenes basadas en Ubuntu 24.04; Redis utiliza la imagen `redis:7.4-alpine`. El Dockerfile y el archivo Compose preparan las dependencias necesarias, incluido GNAT para la compilación y `redis-cli` para la comunicación.

## Declaración de uso de IA

Utilizamos Codex y Claude como apoyo durante el obligatorio. Codex, con modelos de la familia GPT-6, se utilizó para consultar conceptos, revisar e implementar código, realizar verificaciones y preparar documentación. Claude, mediante **[COMPLETAR: herramienta utilizada y modelos, si se conocen]**, se utilizó para **[COMPLETAR: usos principales]**. Como contexto proporcionamos la letra, material de clase, apuntes, transcripciones y código del proyecto.

La IA participó en la generación y modificación de fragmentos de código, la explicación de mecanismos de sincronización y comunicación, y la revisión de alternativas. También la utilizamos para detectar problemas y contrastar las soluciones con los requisitos y los contenidos del curso.

No aceptamos todas sus propuestas: cuestionamos y sustituimos construcciones que se apartaban del material de clase o agregaban complejidad innecesaria. Todo lo referente a la implementación y ejecución fue decidido por nosotros con investigación y propuestas de la IA.
