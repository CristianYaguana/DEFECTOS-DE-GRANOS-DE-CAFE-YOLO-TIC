## Descripción

El proyecto tiene como finalidad evaluar comparativamente el desempeño de cuatro variantes de modelos YOLO aplicadas a la identificación de defectos físicos presentes en granos verdes de café arábigo de la provincia de Loja, Ecuador.

El repositorio reúne los recursos utilizados durante el desarrollo experimental, incluyendo código, configuraciones y archivos relacionados con el entrenamiento, validación y evaluación de los modelos, así como el código fuente de la aplicación desarrollada a partir de los resultados de la investigación.

## Dataset

El conjunto de datos utilizado en los experimentos contiene imágenes de granos verdes de café arábigo de la provincia de Loja.

El dataset se encuentra disponible públicamente en Kaggle:

**Dataset:** Defectos de grano de café de la provincia de Loja

**Enlace:**

https://www.kaggle.com/datasets/cristianyagg/defectos-grano-de-cafe-de-la-provincia-de-loja

El conjunto de datos está organizado en los subconjuntos:

- `train`: datos utilizados para el entrenamiento.
- `valid`: datos utilizados para la validación.
- `test`: datos utilizados para la evaluación.

Las anotaciones son de tipo **poligonal**, por lo que el dataset está preparado para tareas de segmentación de objetos.

El dataset contiene las siguientes nueve clases:

```text
agrio_parcial
broca_leve_severa
cereza_seca
concha
cortado
grano_negro
negro_parcial
normal
por_hongo
