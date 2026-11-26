# ConectaSucre — Propuesta técnica de base de datos vectorial

**Componente:** Persistencia vectorial y búsqueda semántica  
**Tecnología propuesta:** MongoDB Atlas Vector Search  
**Estado:** Diseño técnico; implementación y pruebas pendientes  
**Convención:** Identificadores técnicos en inglés; documentación en español.

## 1. Contexto y problemática

ConectaSucre organiza la distribución de mercancías mediante pedidos, despachos, vehículos, conductores, rutas y entregas. Los incidentes registrados durante estas operaciones pueden describirse con vocabulario diferente aun cuando correspondan a situaciones similares. Una búsqueda SQL como `LIKE '%daño%'` depende de coincidencias textuales y puede omitir descripciones sobre averías, recalentamiento del motor o fallas del radiador.

El apartado de bases de datos vectoriales del documento docente *Modelo de Negocio 6 – ConectaSucre*, páginas 7–8, solicita plantear un caso de búsqueda semántica, seleccionar cinco descripciones de incidentes de transporte reales en carreteras de Sucre y explicar la insuficiencia de las coincidencias exactas frente a la proximidad mediante embeddings. El requisito funcional RF10, numerado en nuestra matriz de trazabilidad, corresponde a permitir búsqueda semántica de incidentes.

## 2. Objetivo y alcance

Diseñar un componente de recuperación de antecedentes logísticos mediante representaciones vectoriales de descripciones textuales, que permita consultar incidentes similares por significado y recuperar sus metadatos y fuentes.

El alcance inicial comprende un corpus de cinco reportes reales verificables, un modelo de embeddings multilingüe preentrenado, una colección independiente, un índice vectorial y un script de consulta. No se propone entrenar un modelo, construir un chatbot, generar respuestas con un LLM ni modificar las transacciones del sistema relacional. La selección efectiva de los cinco reportes y la ejecución del prototipo permanecen pendientes; los ejemplos de este documento son ilustrativos.

## 3. Entidades analizadas y procedencia de los datos

La entidad central es `incidents`, perteneciente al grupo de seguimiento y auditoría del modelo relacional. Se analizaron sus relaciones con la ejecución logística y los recursos de transporte. El modelo documental aporta información complementaria de estructura variable.

| Fuente | Grupo funcional | Datos relevantes | Participación propuesta |
|---|---|---|---|
| `incidents` | Seguimiento y auditoría | `incident_id`, `incident_type`, `description`, `incident_date`, `delay_minutes`, referencias a despacho, entrega o ruta | Fuente principal de futuras descripciones operativas y clasificación de incidentes. |
| `dispatch_assignments` | Ejecución logística | `dispatch_id`, `order_id`, `vehicle_id`, `driver_id`, `route_id`, estado del despacho | Contexto y trazabilidad del incidente cuando existe una asociación válida. |
| `routes` | Recursos de transporte | `route_id` e información descriptiva de origen, destino y recorrido | Contexto geográfico para filtros o visualización. |
| `deliveries` | Ejecución logística | `delivery_id`, `dispatch_id`, resultado y observaciones de entrega | Contexto de devoluciones, daños y novedades en entregas. |
| `tracking_events` | Modelo NoSQL documental | `dispatch_id`, `incident_id`, `event_type`, `description`, `event_date`, `delay_minutes`, `details`, `evidence` | Fuente complementaria futura para enriquecer descripciones de eventos. |
| Reportes públicos verificables | Corpus académico externo | Descripción, fecha, municipio y URL de la fuente | Fuente inicial de los cinco incidentes reales exigidos por el docente. |

Las cuatro tablas relacionales permanecen en MySQL; no se trasladan ni se reemplazan. Las demás entidades del sistema no necesitan indexarse para este caso de uso. Los 250 documentos sintéticos existentes en `tracking_events` no constituyen reportes reales y no sustituyen el corpus exigido. Sus identificadores no han sido cotejados con MySQL.

En la fase inicial, los reportes externos no tendrán identificadores de incidentes internos inventados. En una futura integración se podrán incorporar `incident_id`, `dispatch_id` o `tracking_event_id` únicamente cuando las referencias sean comprobables. Si un incidente se relaciona directamente con una ruta o entrega, no se presumirá que tiene un despacho asociado.

## 4. Arquitectura de persistencia

Se propone conservar la arquitectura de persistencia políglota, con responsabilidades independientes:

| Componente | Responsabilidad | Estado |
|---|---|---|
| MySQL (`conectasucre_ddl`) | Operaciones transaccionales, relaciones y reglas de negocio | Implementado según las pruebas reportadas por el equipo. |
| MongoDB Atlas (`conectasucre_nosql.tracking_events`) | Bitácora de novedades con detalles flexibles | Implementado: validación, 250 documentos y CRUD. |
| MongoDB Atlas (`conectasucre_vectorial.incident_embeddings`) | Recuperación semántica mediante vectores | Propuesto. |
| Python y modelo de embeddings | Transformación de texto en vectores y ejecución de consultas | Propuesto. |

### 4.1. Arquitectura lógica

```text
FASE INICIAL
Reportes públicos verificados (5)
          |
          v
Preparación y validación de descripciones
          |
          v
Python + Sentence Transformers (CPU)
          |
          v
PyMongo -> MongoDB Atlas / incident_embeddings
                         |
                         v
                Índice Vector Search
                         ^
                         |
Consulta -> mismo modelo de embeddings -> búsqueda -> resultados

INTEGRACIÓN FUTURA (no implementada)
MySQL / incidents ------------> extracción y validación de referencias
MongoDB / tracking_events ----> enriquecimiento opcional de texto
                                -> generación/actualización de embeddings
```

La búsqueda no modifica pedidos, despachos ni estados operativos. El índice vectorial es una proyección de lectura especializada y puede reconstruirse a partir de sus fuentes. La futura migración relacional a PostgreSQL no exige cambiar el modelo de embeddings; sí requeriría adaptar el conector de extracción y comprobar los identificadores.

### 4.2. Arquitectura de despliegue

El script Python se ejecutaría en un entorno virtual local, utilizando CPU y conexión TLS a Atlas mediante PyMongo. El almacenamiento y el índice se alojarían en el clúster `ConectaSucre`, sujeto a verificar disponibilidad, límites y compatibilidad de Vector Search en el plan contratado. Compass serviría para inspeccionar documentos; Atlas para administrar el índice. No se requiere desplegar un backend adicional ni contratar una API de IA para generar los vectores localmente.

## 5. Selección tecnológica

| Tecnología | Función | Justificación |
|---|---|---|
| MongoDB Atlas Vector Search | Indexación y recuperación vectorial | Aprovecha la infraestructura existente y permite conservar vectores y metadatos juntos. |
| Python | Preparación de datos y scripts | Permite una implementación reproducible y sencilla. |
| Sentence Transformers | Inferencia del modelo de embeddings | Facilita obtener representaciones numéricas de texto sin entrenar un modelo propio. |
| `sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2` | Modelo de embeddings | Modelo multilingüe de 384 dimensiones, adecuado para experimentar con descripciones en español. |
| PyMongo | Acceso a MongoDB | Permite insertar documentos y ejecutar agregaciones vectoriales. |
| MongoDB Compass | Inspección de datos | Herramienta ya utilizada por el equipo. |
| `python-dotenv` | Configuración local | Permite cargar la URI desde variables de entorno sin incluir credenciales en código. |

Se prefiere Atlas frente a incorporar Qdrant, Chroma o pgvector porque el alcance es reducido y ya existe un clúster MongoDB. Esta decisión reduce componentes administrativos, pero no demuestra superioridad en latencia, precisión ni costo a gran escala. Si el plan actual no admite las operaciones requeridas, deberá evaluarse un entorno compatible antes de implementar.

## 6. Modelo conceptual, lógico y físico

Conceptualmente, cada documento representa un reporte textual de incidente junto con su representación semántica. Una consulta puede recuperar varios reportes y un reporte puede ser pertinente para varias consultas. No se necesita una colección de consultas persistentes ni una relación SQL adicional.

| Elemento | Configuración propuesta |
|---|---|
| Base de datos | `conectasucre_vectorial` |
| Colección | `incident_embeddings` |
| Índice vectorial | `idx_incident_embedding` |
| Campo vectorial | `embedding` |
| Dimensiones | 384 |
| Métrica | Coseno (`cosine`) |
| Búsqueda inicial | Vecinos más cercanos exactos (ENN), si el despliegue es compatible |
| Resultados por consulta | 3, ajustable al corpus |

### 6.1. Diccionario de datos

| Campo | Tipo BSON | Restricción propuesta | Finalidad |
|---|---|---|---|
| `_id` | ObjectId | Único, generado por MongoDB | Identificación física. |
| `incident_type` | String | No vacío | Clasificación del incidente. |
| `description` | String | No vacío | Texto descriptivo utilizado para generar el vector. |
| `municipality` | String / Null | Municipio verificable; null si la fuente no lo identifica | Contexto geográfico. |
| `event_date` | Date / Null | Fecha de ocurrencia verificable; no confundir con publicación | Contexto temporal. |
| `source_url` | String | URL verificable | Trazabilidad del reporte público. |
| `embedding` | Array de Double | Exactamente 384 números finitos | Representación vectorial. |
| `source_id` | String | Único | Identificador estable del reporte para evitar duplicados en recargas. |
| `embedding_model` | String | Modelo utilizado | Reproducibilidad y control de versiones. |

Los dos últimos atributos amplían el diseño inicial para facilitar recargas idempotentes y trazabilidad del modelo. Las referencias internas serían extensiones opcionales futuras, no requisitos del corpus público inicial. Se propone un índice B-tree único sobre `source_id`, independiente del índice vectorial, y un validador JSON Schema para los campos y la longitud del arreglo. La comprobación de números finitos, URLs y procedencia también corresponde al script de carga.

### 6.2. Ejemplo conceptual de documento

```text
_id: ObjectId generado por MongoDB
source_id: identificador estable del reporte
incident_type: MECHANICAL_FAILURE
description: Motor recalentado durante el recorrido
municipality: municipio verificado en la fuente
event_date: fecha comprobada del incidente
source_url: URL real del reporte
embedding_model: sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2
embedding: arreglo de 384 números generados por el modelo
```

Este ejemplo no representa un incidente real seleccionado ni un documento listo para importar. No deben rellenarse los vectores con valores aleatorios ni presentar una URL ficticia como evidencia.

## 7. Preparación del corpus y generación de embeddings

1. Seleccionar cinco incidentes reales de transporte en carreteras de Sucre, conservando enlaces a fuentes verificables.
2. Redactar una descripción fiel y breve de cada incidente, sin añadir causas o datos que la fuente no confirme.
3. Registrar identificador estable, categoría, municipio, fecha del incidente y URL; dejar valores desconocidos como nulos cuando corresponda.
4. Eliminar espacios innecesarios y duplicados, conservando negaciones, acentos, términos técnicos y contexto significativo. No se requiere eliminar palabras vacías ni traducir al inglés.
5. Generar un vector de 384 componentes para cada `description` utilizando el mismo modelo y configuración.
6. Validar longitud, valores finitos y norma no nula; almacenar el documento junto con su vector y modelo.

Un embedding es una representación numérica densa aprendida por un modelo preentrenado. No es una codificación manual de categorías ni una lista de palabras clave. La representación aproxima relaciones semánticas y puede cometer errores. Se recomienda registrar la revisión exacta del modelo y las versiones de dependencias durante la implementación. Si una descripción excede la longitud admitida por el modelo, deberá resumirse fielmente o diseñarse una estrategia de fragmentación antes de indexarla.

## 8. Similitud e indexación

La similitud coseno se expresa como:

```text
cos(A,B) = (A · B) / (||A|| × ||B||)
```

Compara la orientación de dos vectores no nulos. Con vectores normalizados, el producto escalar coincide con la similitud coseno. MongoDB devuelve una puntuación de búsqueda propia; no debe interpretarse como probabilidad, porcentaje de certeza o demostración de que dos incidentes son idénticos.

Para cinco documentos se propone búsqueda exacta (ENN), que compara los vectores elegibles sin aproximación. Para un corpus mucho mayor puede evaluarse ANN con HNSW, ajustando `numCandidates` y midiendo la recuperación frente a ENN. No se justifica optimizar anticipadamente un corpus de cinco elementos.

### 8.1. Definición del índice vectorial

Crear en Atlas un índice de tipo **Vector Search**, llamado `idx_incident_embedding`, asociado a `conectasucre_vectorial.incident_embeddings`:

```json
{
  "fields": [
    {"type": "vector", "path": "embedding", "numDimensions": 384, "similarity": "cosine"},
    {"type": "filter", "path": "incident_type"},
    {"type": "filter", "path": "municipality"},
    {"type": "filter", "path": "event_date"}
  ]
}
```

Los campos `filter` permitirían restringir la búsqueda por categoría, municipio o fecha sin vectorizar esos metadatos. Antes de ejecutar búsquedas, verificar que el índice esté disponible y consultable. Esta configuración es propuesta y no se ha aplicado al clúster.

## 9. Implementación prevista (código de referencia)

### 9.1. Entorno local

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install sentence-transformers pymongo python-dotenv
```

Crear `.env` con `MONGODB_URI` configurada de forma privada. Incluir `.env` y `.venv/` en `.gitignore`. El archivo `incidents.json` deberá contener únicamente los cinco reportes reales recopilados, sin embeddings iniciales, con los campos `source_id`, `incident_type`, `description`, `municipality`, `event_date` (YYYY-MM-DD o null) y `source_url`.

### 9.2. Generación y carga (`generate_embeddings.py`)

```python
import json
import math
import os
from datetime import datetime, timezone
from urllib.parse import urlparse
from dotenv import load_dotenv
from pymongo import MongoClient
from sentence_transformers import SentenceTransformer

load_dotenv()
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
model = SentenceTransformer(MODEL, device="cpu")

with open("incidents.json", encoding="utf-8") as f:
    records = json.load(f)

if len(records) != 5 or len({r["source_id"] for r in records}) != 5:
    raise ValueError("Se requieren cinco reportes con identificadores distintos")

documents = []
for record in records:
    description = " ".join(record["description"].split())
    url = urlparse(record["source_url"])
    if not description or not record["incident_type"].strip() or not record["source_id"].strip():
        raise ValueError("Identificador, descripción y categoría obligatorios")
    if url.scheme not in ("http", "https") or not url.netloc:
        raise ValueError("URL inválida")
    vector = model.encode(description, normalize_embeddings=True).tolist()
    if len(vector) != 384 or not all(math.isfinite(x) for x in vector) or not any(vector):
        raise ValueError("Embedding inválido")
    date = record.get("event_date")
    documents.append({
        "source_id": record["source_id"],
        "incident_type": record["incident_type"],
        "description": description,
        "municipality": record.get("municipality"),
        "event_date": datetime.strptime(date, "%Y-%m-%d").replace(tzinfo=timezone.utc) if date else None,
        "source_url": record["source_url"],
        "embedding_model": MODEL,
        "embedding": vector,
    })

with MongoClient(os.environ["MONGODB_URI"], serverSelectionTimeoutMS=10000) as client:
    collection = client["conectasucre_vectorial"]["incident_embeddings"]
    collection.create_index("source_id", unique=True)
    for document in documents:
        collection.update_one({"source_id": document["source_id"]}, {"$set": document}, upsert=True)
```

El código comprueba la sintaxis de la URL, no la veracidad del reporte: esa revisión es manual. La fecha sin hora se almacena como fecha a medianoche UTC por convención, no como hora real de ocurrencia. La carga por `upsert` evita duplicados por identificador, pero no elimina reportes retirados del archivo; una sustitución del corpus exige conciliación explícita.

### 9.3. Consulta semántica (`semantic_search.py`)

```python
import os
from dotenv import load_dotenv
from pymongo import MongoClient
from sentence_transformers import SentenceTransformer

load_dotenv()
MODEL = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
model = SentenceTransformer(MODEL, device="cpu")
query = input("Descripción del incidente: ").strip()
if not query:
    raise ValueError("La consulta no puede estar vacía")
vector = model.encode(query, normalize_embeddings=True).tolist()

pipeline = [
    {"$vectorSearch": {
        "index": "idx_incident_embedding",
        "path": "embedding",
        "queryVector": vector,
        "exact": True,
        "limit": 3
    }},
    {"$project": {
        "_id": 0, "source_id": 1, "incident_type": 1,
        "description": 1, "municipality": 1, "event_date": 1,
        "source_url": 1, "score": {"$meta": "vectorSearchScore"}
    }}
]

with MongoClient(os.environ["MONGODB_URI"], serverSelectionTimeoutMS=10000) as client:
    collection = client["conectasucre_vectorial"]["incident_embeddings"]
    for result in collection.aggregate(pipeline):
        print(result)
```

`$vectorSearch` se coloca como primera etapa de la agregación. Si ENN no está disponible, se deberá verificar la versión y las capacidades del despliegue antes de seleccionar una alternativa ANN compatible. El código no ha sido ejecutado. La compatibilidad del modelo, el índice y el servidor deberá comprobarse en la implementación.

## 10. Caso de uso y patrón de acceso

**Actor:** operador logístico o responsable de despacho.  
**Entrada:** descripción libre de una novedad, por ejemplo, «problemas de enfriamiento del motor».  
**Proceso:** convertir la consulta con el mismo modelo, comparar el vector con los incidentes indexados, ordenar por similitud y recuperar los tres resultados más cercanos.  
**Salida:** descripciones, categoría, ubicación, fecha, fuente y puntuación.  
**Resultado esperado:** localizar antecedentes sobre sobrecalentamiento o averías del radiador aunque no contengan literalmente la consulta.

La coincidencia exacta es útil para categorías, códigos e identificadores; la búsqueda vectorial es complementaria cuando interesa el significado. Si ninguna descripción es pertinente, mostrar que no se encontraron antecedentes relevantes; el umbral se calibrará con pruebas y no se fijará arbitrariamente como porcentaje de confianza.

## 11. Integración, consistencia y mantenimiento

La primera fase utilizará una carga manual de reportes verificados. Para una evolución futura, un proceso de extracción por lotes podría leer `incidents` y, cuando corresponda, enriquecer sus descripciones con `tracking_events` y metadatos relacionales. Se propone un patrón de proyección de lectura derivada (similar a CQRS), con consistencia eventual: la fuente operativa conserva la autoridad y la colección vectorial se actualiza después de los cambios.

- Alta: validar la fuente, generar embedding y realizar upsert.
- Cambio de descripción: recalcular el embedding; si solo cambian metadatos no incluidos en el texto, actualizar esos campos.
- Baja: retirar la proyección según la política de conservación de la fuente.
- Cambio de modelo: regenerar todos los embeddings y reconstruir un índice compatible; no mezclar espacios vectoriales.
- Fallos: registrar errores, reintentar operaciones idempotentes y conciliar identificadores con las fuentes.

No hay FK entre motores ni transacciones distribuidas implementadas. No se propone modificar triggers SQL para enviar llamadas remotas. No se requiere un sistema de mensajería o CDC en el prototipo.

## 12. Infraestructura, seguridad y escalabilidad

Se utilizarían credenciales con permisos mínimos sobre la base vectorial, acceso de red restringido y TLS con verificación de certificados. Las URI y contraseñas no deben publicarse en GitHub. Evitar incluir nombres, teléfonos, documentos personales o imágenes de víctimas en el corpus si no son necesarios para la búsqueda.

Con cinco vectores no se propone particionamiento físico ni una clave de shard: una colección sin fragmentación es suficiente para el alcance. La replicación queda bajo la configuración administrada de Atlas según el plan disponible; no se ha configurado ni probado una política personalizada. Si el volumen aumenta, evaluar distribución, memoria del índice, selectividad de filtros, latencia y recuperación antes de cambiar el despliegue. Conservar el corpus original y las configuraciones del modelo permite reconstruir el índice; la disponibilidad de respaldos administrados depende del plan y debe verificarse.

## 13. Plan de pruebas y criterios de aceptación

| Prueba | Criterio de aceptación |
|---|---|
| Verificación de fuentes | Cinco reportes reales distintos, cada uno respaldado por una fuente consultable. |
| Carga inicial | Cinco documentos válidos y sin duplicados en una colección inicialmente vacía. |
| Dimensiones | Cada embedding y vector de consulta contiene 384 componentes finitos. |
| Índice | Índice vectorial disponible y consultable. |
| Paráfrasis | Consultas con vocabulario distinto recuperan antecedentes pertinentes, cuando existen en el corpus. |
| Consulta no relacionada | Se identifica la ausencia de resultados pertinentes; no se fuerza una interpretación. |
| Comparación textual | Comparar los resultados con búsqueda por coincidencia literal sobre el mismo corpus. |
| Filtros | Cuando se aplican, los resultados respetan municipio, categoría o fecha. |
| Recarga | Repetir la carga no crea duplicados por `source_id`. |
| Evaluación | Registrar resultados, pertinencia manual, puntuaciones y latencia medida. |

Como evaluación inicial puede calcularse Precision@3 = resultados pertinentes entre los tres recuperados / 3 (siempre que se recuperen tres). También puede registrarse Recall@3 con un conjunto de relevancia etiquetado manualmente. Con cinco reportes estas métricas son ilustrativas, no evidencia de generalización ni superioridad estadística. No existen resultados medidos todavía.

## 14. Organización de archivos prevista

```text
vectorial/
├── Documentacion_Vectorial_ConectaSucre.md
├── incidents.json
├── generate_embeddings.py
├── vector_index.json
├── semantic_search.py
├── requirements.txt
├── .env.example
├── .gitignore
└── evidence/
```

Únicamente este documento se entrega en esta fase. Los demás archivos son entregables previstos; los fragmentos de código anteriores sirven como especificación de referencia. Durante la implementación se deberán registrar versiones exactas en `requirements.txt` y guardar evidencias sin credenciales.

## 15. Comparación y justificación técnica

| Criterio | Relacional (MySQL) | Documental (MongoDB) | Vectorial (Atlas Vector Search) |
|---|---|---|---|
| Necesidad principal | Integridad de operaciones y relaciones | Eventos heterogéneos | Recuperación por significado |
| Unidad de datos | Filas y tablas | Documentos BSON | Documentos con embeddings y metadatos |
| Patrón de acceso | JOIN, filtros, transacciones | Filtros y atributos anidados | Vecinos más cercanos y filtros |
| Consultas textuales | LIKE o búsqueda de texto según configuración | Filtros o búsqueda textual | Proximidad semántica estimada |
| Ventaja para ConectaSucre | Consistencia y control de negocio | Flexibilidad de novedades | Identificación de antecedentes con vocabulario distinto |
| Costo adicional | Motor existente | Clúster existente | Generación e indexación de vectores; sujeto a límites del plan |
| Limitaciones | Coincidencia literal no equivale a significado | Flexibilidad no implica comprensión semántica | Errores de pertinencia, actualización de embeddings y evaluación necesaria |

La eficiencia esperada se refiere a la adecuación del patrón de acceso y a una menor dependencia de coincidencias literales. No se afirma que Vector Search sea más rápido que SQL o que siempre recupere mejores resultados. La selección se justifica por el problema específico y la reutilización de infraestructura.

## 16. Estado y conclusión

La propuesta define el objetivo, las entidades analizadas, la procedencia de datos, el modelo físico, la arquitectura, la estrategia de embeddings, la búsqueda, la integración y las pruebas previstas. Quedan pendientes la selección y verificación de cinco incidentes reales, la comprobación del plan Atlas, la creación de la colección e índice, la generación de vectores y las búsquedas funcionales. La sincronización con MySQL y MongoDB documental constituye una evolución futura, no una característica ya implementada.

La base vectorial complementaría la gestión transaccional y documental de ConectaSucre mediante una proyección especializada para recuperar antecedentes logísticos. El modelo relacional conserva la integridad del negocio y el documental la flexibilidad de los eventos; el componente vectorial agrega una capacidad de búsqueda distinta.

## 17. Referencias

- Documento docente suministrado: *Modelo de Negocio 6 – ConectaSucre*, apartado 4 (requisitos) y apartado 6, bases de datos vectoriales, pp. 7–8.
- Informe interno: *ConectaSucre_Informe_Tecnico_Final.docx*, capítulo 2, propuesta vectorial.
- Documentación interna: *Documentacion_NoSQL_ConectaSucre.md*.
- MongoDB, [Vector Search — documentación oficial](https://www.mongodb.com/docs/vector-search/).
- MongoDB, [Definición de índices Vector Search](https://www.mongodb.com/docs/vector-search/indexes/vector-search-type/).
- MongoDB, [Consultas con $vectorSearch](https://www.mongodb.com/docs/vector-search/query/aggregation-stages/vector-search-stage/).
- Sentence Transformers, [Ficha del modelo paraphrase-multilingual-MiniLM-L12-v2](https://huggingface.co/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2).
