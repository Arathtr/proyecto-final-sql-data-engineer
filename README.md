# Proyecto Final — SQL for Data Engineer

Pipeline de datos con arquitectura **Medallion (Bronce → Plata → Oro)** sobre SQL Server, construido a partir de 10 archivos CSV de una cadena de pizzerías (ventas, clientes, productos, recetas, inventario, personal y turnos).

## Arquitectura

![Diagrama del modelo de datos - Capa Oro](diagramas/diagrama_modelo_datos_oro.png)

| Capa | Propósito | Regla principal |
|---|---|---|
| 🥉 **Bronce** | Ingesta cruda desde los CSV, sin transformar | Todo como `VARCHAR`, columna `FECHA_CARGA` obligatoria |
| 🥈 **Plata** | Limpieza, tipado real, deduplicación | `TRY_CAST`, `PRIMARY KEY` / `FOREIGN KEY`, reglas de negocio documentadas abajo |
| 🥇 **Oro** | Modelo estrella (constelación de hechos) | Surrogate keys `IDENTITY`, listo para conectar a un dashboard |

## Estructura del repositorio

```
├── scripts/
│   ├── 01_bronze/      # CREATE TABLE + BULK INSERT (vía vistas) por cada entidad
│   ├── 02_silver/      # DROP + CREATE + CONSTRAINTS + INSERT (limpieza y tipado)
│   └── 03_gold/        # DROP + CREATE + INSERT (dimensiones, hechos, bridge table)
├── diagramas/
│   ├── diagrama_modelo_datos_oro.png
│   └── diagrama_modelo_datos_oro.svg
└── README.md
```

## Cómo ejecutar

En SQL Server Management Studio (SSMS), en este orden:

1. **Bronce**: crea la base de datos y los 3 schemas (`bronze`, `silver`, `gold`), luego corre `scripts/01_bronze/*.sql`. Los `BULK INSERT` apuntan a los 10 CSV — ajusta la ruta local antes de ejecutar.
2. **Plata**: corre `scripts/02_silver/*.sql`. Empieza con los `DROP TABLE IF EXISTS` (por si necesitas reconstruir desde cero), sigue con los `CREATE TABLE`, las `FOREIGN KEY` y finalmente los `INSERT` con la limpieza aplicada.
3. **Oro**: corre `scripts/03_gold/*.sql`, mismo patrón (DROP → CREATE → INSERT).

Cada script es idempotente: se puede volver a ejecutar el bloque completo de una capa sin dejar residuos, gracias al `DROP TABLE IF EXISTS` inicial.

## Modelo de datos (Capa Oro)

**Dimensiones:** `dim_cliente`, `dim_producto`, `dim_direccion`, `dim_empleado`, `dim_turno`, `dim_ingrediente`, `dim_fecha` (generada, dimensión conformada compartida por ambos hechos).

**Hechos:**
- `fact_ventas` — grano: un producto dentro de un pedido. Métricas: `cantidad`, `monto_total`.
- `fact_rotacion_personal` — grano: una asignación turno-empleado dentro de una rotación (factless fact).

**Tabla puente:** `receta_producto_ingrediente` — resuelve la relación muchos-a-muchos entre productos e ingredientes.

## Decisiones de limpieza y calidad de datos

Durante la construcción de la capa Plata se identificaron y resolvieron los siguientes problemas de calidad, documentados aquí por trazabilidad:

1. **IDs alfanuméricos con prefijo** (`ING001`, `it001`, `sh0001`, `st0001`, `ORD_00001`, `r00001`): se mantuvieron como `VARCHAR`, no se forzaron a `INT`.
2. **`Direcciones` sin columna de ID propia** en el CSV origen: se generó un identificador (`IDENTITY`) en el orden de lectura del archivo, asumiendo que ese orden corresponde a la posición usada como `ID_DIRECCION` en Pedidos (validado por rango y por conteo de coincidencias).
3. **Caracteres invisibles** (retorno de carro `CHAR(13)`) pegados a la última columna de varios CSV, por un desajuste entre el `ROWTERMINATOR` usado en `BULK INSERT` y el terminador real del archivo. Se limpiaron con `REPLACE` antes de convertir tipos.
4. **Líneas duplicadas dentro de un mismo pedido** (mismo producto repetido en más de una fila): se consolidaron sumando las cantidades (`GROUP BY` + `SUM`) en vez de mantenerlas como filas separadas, preservando la unicidad de `(ID_PEDIDO, ID_PRODUCTO)`.
5. **`Receta` referencia productos por SKU, no por ID interno**: se resolvió el cruce a través de la columna `SKU` de `Productos` en vez de `ID_PRODUCTO`.
6. **`Inventario`** se incorporó como atributo (`stock_actual`) dentro de `dim_ingrediente` en la capa Oro, en lugar de mantenerse como tabla independiente, por representar una foto puntual del stock sin dimensión temporal propia.

## Autor

Martín Arath Taboada Rivera — Proyecto Final, curso SQL for Data Engineer (SQL Server).
