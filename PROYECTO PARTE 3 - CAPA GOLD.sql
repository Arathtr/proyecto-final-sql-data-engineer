USE ProyectoFinalSQL;
GO

/*ELIMINAR TABLAS*/

DROP TABLE IF EXISTS gold.receta_producto_ingrediente;
DROP TABLE IF EXISTS gold.fact_rotacion_personal;
DROP TABLE IF EXISTS gold.fact_ventas;
DROP TABLE IF EXISTS gold.dim_ingrediente;
DROP TABLE IF EXISTS gold.dim_turno;
DROP TABLE IF EXISTS gold.dim_empleado;
DROP TABLE IF EXISTS gold.dim_direccion;
DROP TABLE IF EXISTS gold.dim_producto;
DROP TABLE IF EXISTS gold.dim_cliente;
DROP TABLE IF EXISTS gold.dim_fecha;
GO



CREATE TABLE gold.dim_fecha
(
    fecha_key    INT PRIMARY KEY,       -- formato YYYYMMDD
    fecha        DATE NOT NULL UNIQUE,
    anio         INT,
    mes          INT,
    dia          INT,
    nombre_mes   VARCHAR(20),
    dia_semana   VARCHAR(20),
    trimestre    INT
);
GO

DECLARE @FechaInicio DATE, @FechaFin DATE;

SELECT @FechaInicio = MIN(f), @FechaFin = MAX(f)
FROM (
    SELECT FECHA_CREACION AS f FROM silver.PEDIDOS
    UNION ALL
    SELECT FECHA AS f FROM silver.ROTACION_TURNOS
) x;

;WITH Fechas AS
(
    SELECT @FechaInicio AS fecha
    UNION ALL
    SELECT DATEADD(DAY, 1, fecha)
    FROM Fechas
    WHERE fecha < @FechaFin
)
INSERT INTO gold.dim_fecha (fecha_key, fecha, anio, mes, dia, nombre_mes, dia_semana, trimestre)
SELECT
    CAST(FORMAT(fecha, 'yyyyMMdd') AS INT),
    fecha,
    YEAR(fecha), MONTH(fecha), DAY(fecha),
    DATENAME(MONTH, fecha),
    DATENAME(WEEKDAY, fecha),
    DATEPART(QUARTER, fecha)
FROM Fechas
OPTION (MAXRECURSION 0);
GO

-- dim_cliente
CREATE TABLE gold.dim_cliente
(
    cliente_key      INT IDENTITY(1,1) PRIMARY KEY,
    id_cliente_neg   INT NOT NULL UNIQUE,
    nombre_cliente   VARCHAR(200),
    apellido_cliente VARCHAR(200)
);
GO
INSERT INTO gold.dim_cliente (id_cliente_neg, nombre_cliente, apellido_cliente)
SELECT ID_CLIENTE, NOMBRE_CLIENTE, APELLIDO_CLIENTE FROM silver.CLIENTES;
GO

-- dim_producto
CREATE TABLE gold.dim_producto
(
    producto_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_producto_neg  VARCHAR(20) NOT NULL UNIQUE,
    sku              VARCHAR(200),
    nombre_producto  VARCHAR(200),
    categoria        VARCHAR(200),
    forma            VARCHAR(200),
    precio           FLOAT
);
GO
INSERT INTO gold.dim_producto (id_producto_neg, sku, nombre_producto, categoria, forma, precio)
SELECT ID_PRODUCTO, SKU, NOMBRE_PRODUCTO, CAT_PRODUCTO, FORMA_PRODUCTO, PRECIO_PRODUCTO FROM silver.PRODUCTOS;
GO

-- dim_direccion
CREATE TABLE gold.dim_direccion
(
    direccion_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_direccion_neg  INT NOT NULL UNIQUE,
    direccion_linea1  VARCHAR(200),
    direccion_linea2  VARCHAR(200),
    ciudad            VARCHAR(200)
);
GO
INSERT INTO gold.dim_direccion (id_direccion_neg, direccion_linea1, direccion_linea2, ciudad)
SELECT ID_DIRECCION, DIR_DELIVERY_PRIN, DIR_DELIVERY_SEC, CIUDAD_DELIVERY FROM silver.DIRECCIONES;
GO

-- dim_empleado
CREATE TABLE gold.dim_empleado
(
    empleado_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_empleado_neg  VARCHAR(20) NOT NULL UNIQUE,
    nombres          VARCHAR(200),
    apellidos        VARCHAR(200),
    cargo            VARCHAR(200),
    tarifa_hora      FLOAT
);
GO
INSERT INTO gold.dim_empleado (id_empleado_neg, nombres, apellidos, cargo, tarifa_hora)
SELECT ID_EMPLEADO, NOMBRES, APELLIDOS, CARGO, TARIFA_HORA FROM silver.EMPLEADOS;
GO

-- dim_turno
CREATE TABLE gold.dim_turno
(
    turno_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_turno_neg  VARCHAR(20) NOT NULL UNIQUE,
    dia_semana    VARCHAR(200),
    hora_inicio   TIME,
    hora_fin      TIME
);
GO
INSERT INTO gold.dim_turno (id_turno_neg, dia_semana, hora_inicio, hora_fin)
SELECT ID_TURNO, DIA_SEMANA, HORA_INICIO, HORA_FIN FROM silver.TURNOS;
GO

-- dim_ingrediente (con stock desde INVENTARIO)
CREATE TABLE gold.dim_ingrediente
(
    ingrediente_key     INT IDENTITY(1,1) PRIMARY KEY,
    id_ingrediente_neg  VARCHAR(20) NOT NULL UNIQUE,
    nombre_ingrediente  VARCHAR(200),
    peso                VARCHAR(200),
    medida              VARCHAR(200),
    precio              FLOAT,
    stock_actual        INT
);
GO
INSERT INTO gold.dim_ingrediente (id_ingrediente_neg, nombre_ingrediente, peso, medida, precio, stock_actual)
SELECT i.ID_INGRED, i.NOMBRE_INGRED, i.PESO_INGRED, i.MEDIDA_INGRED, i.PRECIO_INGRED, inv.CANTIDAD
FROM silver.INGREDIENTES i
LEFT JOIN silver.INVENTARIO inv ON inv.ID_INGRED = i.ID_INGRED;
GO


-- fact_ventas
CREATE TABLE gold.fact_ventas
(
    fact_id        INT IDENTITY(1,1) PRIMARY KEY,
    id_pedido_neg  VARCHAR(20),
    producto_key   INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    cliente_key    INT FOREIGN KEY REFERENCES gold.dim_cliente(cliente_key),
    direccion_key  INT FOREIGN KEY REFERENCES gold.dim_direccion(direccion_key),
    fecha_key      INT FOREIGN KEY REFERENCES gold.dim_fecha(fecha_key),
    cantidad       INT,
    es_delivery    BIT,
    monto_total    FLOAT
);
GO
INSERT INTO gold.fact_ventas (id_pedido_neg, producto_key, cliente_key, direccion_key, fecha_key, cantidad, es_delivery, monto_total)
SELECT
    p.ID_PEDIDO, dp.producto_key, dc.cliente_key, dd.direccion_key, df.fecha_key,
    p.CANTIDAD, p.FLG_DELIVERY, p.CANTIDAD * dp.precio
FROM silver.PEDIDOS p
INNER JOIN gold.dim_producto dp  ON dp.id_producto_neg  = p.ID_PRODUCTO
INNER JOIN gold.dim_cliente dc   ON dc.id_cliente_neg   = p.ID_CLIENTE
INNER JOIN gold.dim_direccion dd ON dd.id_direccion_neg = p.ID_DIRECCION
INNER JOIN gold.dim_fecha df     ON df.fecha            = p.FECHA_CREACION;
GO

-- fact_rotacion_personal (factless)
CREATE TABLE gold.fact_rotacion_personal
(
    fact_id          INT IDENTITY(1,1) PRIMARY KEY,
    id_rotacion_neg  VARCHAR(20),
    turno_key        INT FOREIGN KEY REFERENCES gold.dim_turno(turno_key),
    empleado_key     INT FOREIGN KEY REFERENCES gold.dim_empleado(empleado_key),
    fecha_key        INT FOREIGN KEY REFERENCES gold.dim_fecha(fecha_key)
);
GO
INSERT INTO gold.fact_rotacion_personal (id_rotacion_neg, turno_key, empleado_key, fecha_key)
SELECT rt.ID_ROTACION, dt.turno_key, de.empleado_key, df.fecha_key
FROM silver.ROTACION_TURNOS rt
INNER JOIN gold.dim_turno dt    ON dt.id_turno_neg    = rt.ID_TURNO
INNER JOIN gold.dim_empleado de ON de.id_empleado_neg = rt.ID_EMPLEADO
INNER JOIN gold.dim_fecha df    ON df.fecha           = rt.FECHA;
GO

CREATE TABLE gold.receta_producto_ingrediente
(
    producto_key    INT FOREIGN KEY REFERENCES gold.dim_producto(producto_key),
    ingrediente_key INT FOREIGN KEY REFERENCES gold.dim_ingrediente(ingrediente_key),
    cantidad_receta INT,
    PRIMARY KEY (producto_key, ingrediente_key)
);
GO
INSERT INTO gold.receta_producto_ingrediente (producto_key, ingrediente_key, cantidad_receta)
SELECT dp.producto_key, di.ingrediente_key, r.CANTIDAD
FROM silver.RECETA r
INNER JOIN gold.dim_producto dp    ON dp.id_producto_neg    = r.ID_PRODUCTO
INNER JOIN gold.dim_ingrediente di ON di.id_ingrediente_neg = r.ID_INGRED;
GO


/*Validación*/

/*Tablas DIM*/
SELECT * FROM gold.dim_fecha;
SELECT * FROM gold.dim_cliente;
SELECT * FROM gold.dim_direccion;
SELECT * FROM gold.dim_empleado;
SELECT * FROM gold.dim_turno;
SELECT * FROM gold.dim_ingrediente;

/*Tablas FACT*/
SELECT * FROM gold.fact_ventas;
SELECT * FROM gold.fact_rotacion_personal;
SELECT * FROM gold.receta_producto_ingrediente;

