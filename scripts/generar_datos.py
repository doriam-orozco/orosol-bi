"""
====================================================================
 DISTRIBUIDORA OROSOL, S.A.
 Generador de datos sintéticos para el proyecto de Business Intelligence
====================================================================

 Simula la operación de una ferretería / distribuidora de materiales
 de construcción con 3 centros de distribución, del 01/01/2023 al
 13/07/2026.

 El script NO reparte números al azar: simula el negocio día a día.
 La demanda genera consumo, el consumo baja el inventario, el
 inventario dispara órdenes de compra, los proveedores entregan con
 retraso variable, y cuando no hay existencia se produce un quiebre.
 Por eso las métricas (fill rate, rotación, quiebres) salen solas y
 son internamente consistentes.

 Salida: 7 archivos CSV en ../data/

 Uso:  python generar_datos.py
====================================================================
"""

import numpy as np
import pandas as pd
from pathlib import Path

# --------------------------------------------------------------------
# CONFIGURACIÓN
# --------------------------------------------------------------------
SEMILLA = 2026              # reproducibilidad: mismos datos en cada corrida
FECHA_INICIO = "2023-01-01"
FECHA_FIN = "2026-07-13"

N_SKUS = 900
N_PROVEEDORES = 35
N_CLIENTES = 400

DIR_SALIDA = Path(__file__).resolve().parent.parent / "data"
DIR_SALIDA.mkdir(parents=True, exist_ok=True)

rng = np.random.default_rng(SEMILLA)

fechas = pd.date_range(FECHA_INICIO, FECHA_FIN, freq="D")
N_DIAS = len(fechas)

print(f"Horizonte: {N_DIAS} días ({FECHA_INICIO} a {FECHA_FIN})")

# --------------------------------------------------------------------
# DIM_CALENDARIO
# --------------------------------------------------------------------
# Nota: la tabla calendario se puede construir también en Power BI con DAX.
# La generamos aquí para que exista en la base y puedas practicar joins
# de fecha en SQL. En Power BI decidirás cuál usar.
MESES_ES = ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
            "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
DIAS_ES = ["Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado", "Domingo"]

dim_calendario = pd.DataFrame({
    "fecha": fechas,
    "anio": fechas.year,
    "trimestre": fechas.quarter,
    "mes": fechas.month,
    "nombre_mes": [MESES_ES[m - 1] for m in fechas.month],
    "dia": fechas.day,
    "dia_semana": fechas.dayofweek + 1,
    "nombre_dia": [DIAS_ES[d] for d in fechas.dayofweek],
    "es_fin_semana": fechas.dayofweek >= 5,
    "anio_mes": fechas.strftime("%Y-%m"),
    # Bandera clave: 2026 es un año PARCIAL. Sin esto, cualquier
    # comparación anual va a mentir. La vas a usar para las medidas YTD.
    "es_anio_completo": fechas.year < 2026,
})

# --------------------------------------------------------------------
# DIM_PROVEEDOR
# --------------------------------------------------------------------
paises = ["Guatemala", "México", "China", "Estados Unidos", "Colombia", "Brasil"]
prob_pais = [0.30, 0.22, 0.25, 0.13, 0.06, 0.04]
# Los proveedores importados tienen lead times mucho más largos.
lead_base_pais = {"Guatemala": 5, "México": 18, "China": 55,
                  "Estados Unidos": 22, "Colombia": 28, "Brasil": 32}

prov_paises = rng.choice(paises, N_PROVEEDORES, p=prob_pais)

dim_proveedor = pd.DataFrame({
    "id_proveedor": np.arange(1, N_PROVEEDORES + 1),
    "nombre_proveedor": [f"Proveedor {i:02d}" for i in range(1, N_PROVEEDORES + 1)],
    "pais": prov_paises,
    "lead_time_objetivo": [lead_base_pais[p] + rng.integers(-3, 6) for p in prov_paises],
})
# Confiabilidad: qué tan bien cumple el lead time prometido (no va a la BD;
# es un parámetro oculto de la simulación, se debe DESCUBRIR con los datos).
_confiabilidad = rng.beta(6, 2, N_PROVEEDORES)

# --------------------------------------------------------------------
# DIM_BODEGA
# --------------------------------------------------------------------
dim_bodega = pd.DataFrame({
    "id_bodega": [1, 2, 3],
    "nombre_bodega": ["CEDI Guatemala", "CEDI Escuintla", "CEDI Quetzaltenango"],
    "region": ["Central", "Sur", "Occidente"],
    "tipo": ["Principal", "Regional", "Regional"],
    "capacidad_m2": [8500, 3200, 4100],
})
peso_bodega = np.array([0.55, 0.18, 0.27])   # participación en la demanda

# --------------------------------------------------------------------
# DIM_PRODUCTO
# --------------------------------------------------------------------
categorias = {
    "Herramienta Manual":    (["Martillos", "Destornilladores", "Llaves", "Alicates"], 45, 900),
    "Herramienta Eléctrica": (["Taladros", "Sierras", "Pulidoras", "Compresores"], 450, 9500),
    "Plomería":              (["Tubería PVC", "Válvulas", "Grifería", "Accesorios"], 12, 850),
    "Material Eléctrico":    (["Cable", "Tomacorrientes", "Breakers", "Iluminación"], 15, 1200),
    "Pinturas":              (["Látex", "Aceite", "Anticorrosivo", "Solventes"], 55, 700),
    "Tornillería":           (["Tornillos", "Pernos", "Clavos", "Anclajes"], 2, 90),
    "Materiales":            (["Cemento", "Block", "Hierro", "Lámina"], 35, 550),
    "Seguridad Industrial":  (["Cascos", "Guantes", "Botas", "Arneses"], 25, 600),
}
pesos_cat = np.array([0.13, 0.09, 0.15, 0.14, 0.08, 0.17, 0.16, 0.08])

cat_names = list(categorias.keys())
sku_cat = rng.choice(cat_names, N_SKUS, p=pesos_cat)

filas_prod = []
for i, cat in enumerate(sku_cat, start=1):
    subcats, cmin, cmax = categorias[cat]
    # Costo con distribución log-normal: muchos baratos, pocos caros. Realista.
    costo = float(np.exp(rng.uniform(np.log(cmin), np.log(cmax))))
    filas_prod.append({
        "id_producto": i,
        "sku": f"ORO-{i:04d}",
        "nombre_producto": f"{rng.choice(subcats)} {rng.choice(['Std','Pro','Heavy','Eco','Max'])} {rng.integers(1,99)}",
        "categoria": cat,
        "subcategoria": rng.choice(subcats),
        "id_proveedor": int(rng.integers(1, N_PROVEEDORES + 1)),
        "costo_unitario": round(costo, 2),
        # Margen: la tornillería y materiales dejan poco; la herramienta deja más.
        "precio_lista": round(costo * rng.uniform(1.22, 1.85), 2),
        "unidad_medida": rng.choice(["Unidad", "Caja", "Metro", "Quintal", "Galón"]),
    })
dim_producto = pd.DataFrame(filas_prod)

# --------------------------------------------------------------------
# DIM_CLIENTE
# --------------------------------------------------------------------
canales = ["Ferretería Minorista", "Constructora", "Gobierno / Licitación"]
prob_canal = [0.62, 0.30, 0.08]
cli_canal = rng.choice(canales, N_CLIENTES, p=prob_canal)
regiones_cli = ["Central", "Sur", "Occidente", "Oriente", "Norte"]

dim_cliente = pd.DataFrame({
    "id_cliente": np.arange(1, N_CLIENTES + 1),
    "nombre_cliente": [f"Cliente {i:03d}" for i in range(1, N_CLIENTES + 1)],
    "canal": cli_canal,
    "segmento": [("Grande" if c == "Gobierno / Licitación"
                  else rng.choice(["Grande", "Mediano", "Pequeño"], p=[0.2, 0.35, 0.45]))
                 for c in cli_canal],
    "region": rng.choice(regiones_cli, N_CLIENTES),
})
# Días de crédito prometidos por canal → base para la fecha prometida de entrega
dias_promesa_canal = {"Ferretería Minorista": 2, "Constructora": 4, "Gobierno / Licitación": 7}

# --------------------------------------------------------------------
# PARÁMETROS OCULTOS DE DEMANDA (no van a la base de datos)
# --------------------------------------------------------------------
# Demanda base por SKU, log-normal: pocos productos mueven casi todo el
# volumen. Esto es lo que hace que la clasificación ABC tenga sentido.
demanda_base = np.exp(rng.normal(-0.30, 1.25, N_SKUS))

# --- ANOMALÍA 1: inventario muerto -------------------------------------
# Un grupo de SKUs pierde su demanda casi por completo. El inventario
# se queda estancado y el capital inmovilizado crece. Sesgado hacia
# categorías caras para que el hallazgo duela en quetzales.
# OJO al matiz: el inventario muerto NO nace de un producto que siempre
# vendió poco (para ese la empresa simplemente compra poco). Nace de un
# producto que SÍ vendía, la empresa compró para esa demanda, y la demanda
# se cayó. El stock queda ahí, comprado, inmóvil. Por eso el colapso ocurre
# a media historia y la política de compra sigue calibrada a la demanda vieja.
peso_muerto = np.where(np.isin(sku_cat, ["Herramienta Eléctrica", "Seguridad Industrial"]), 4.0, 1.0)
peso_muerto = peso_muerto * (demanda_base > np.median(demanda_base))  # solo SKUs que sí vendían
peso_muerto = peso_muerto / peso_muerto.sum()
skus_muertos = rng.choice(N_SKUS, size=60, replace=False, p=peso_muerto)
FECHA_COLAPSO = pd.Timestamp("2025-04-01")
colapso_sku = np.ones(N_SKUS)
colapso_sku[skus_muertos] = 0.03

# --- ANOMALÍA 2: proveedor que se degrada ------------------------------
# Un proveedor confiable empieza a fallar a partir de mediados de 2025.
# No hay ninguna columna que lo diga: hay que compararlo contra sí mismo
# en el tiempo para verlo.
PROV_DEGRADADO = int(rng.integers(1, N_PROVEEDORES + 1))
FECHA_DEGRADACION = pd.Timestamp("2025-06-01")

# --- ANOMALÍA 3: bodega con mal servicio -------------------------------
# El CEDI Escuintla entrega tarde con más frecuencia. Se ve en el OTIF,
# no en ninguna dimensión.
BODEGA_PROBLEMA = 2

# Estacionalidad: en Guatemala la construcción se dispara en temporada
# seca (noviembre–abril) y cae con las lluvias.
factor_mes = np.array([1.18, 1.20, 1.22, 1.15, 0.92, 0.80, 0.85, 0.88, 0.82, 0.95, 1.10, 1.15])
# Crecimiento del negocio: ~9% anual. La empresa crece.
crecimiento_anual = {2023: 1.00, 2024: 1.09, 2025: 1.19, 2026: 1.27}

mes_idx = fechas.month.values - 1
anio_idx = fechas.year.values
factor_dia = np.where(fechas.dayofweek.values >= 5, 0.35, 1.0)   # sábado/domingo flojos

# Multiplicador de demanda para cada día del horizonte
mult_dia = (factor_mes[mes_idx]
            * np.array([crecimiento_anual[a] for a in anio_idx])
            * factor_dia
            * rng.normal(1.0, 0.10, N_DIAS).clip(0.6, 1.4))   # ruido diario

# --------------------------------------------------------------------
# SIMULACIÓN DÍA A DÍA: inventario + ventas
# --------------------------------------------------------------------
# Política de reposición (s, S): cuando la existencia disponible cae bajo
# el punto de reorden s, se pide hasta el nivel objetivo S.
# El lead time del proveedor determina cuándo llega. Si la demanda supera
# la existencia, hay quiebre. Todo lo demás se deriva de aquí.

print("Simulando operación día a día... (esto toma ~1 min)")

# SURTIDO POR BODEGA: el CEDI principal carga todo el catálogo, los
# regionales solo una parte. Así funciona de verdad y además evita
# inflar artificialmente el tamaño de las tablas.
surtido = {
    0: np.arange(N_SKUS),                                        # Guatemala: 900
    1: np.sort(rng.choice(N_SKUS, 320, replace=False)),          # Escuintla: 320
    2: np.sort(rng.choice(N_SKUS, 480, replace=False)),          # Xela: 480
}
sku_de_serie = np.concatenate([surtido[b] for b in range(3)])
bod_de_serie = np.concatenate([np.full(len(surtido[b]), b) for b in range(3)])
n_series = len(sku_de_serie)

# Demanda media diaria por serie
lam = demanda_base[sku_de_serie] * peso_bodega[bod_de_serie] * 0.85
lam = np.maximum(lam, 0.01)

prov_de_sku = dim_producto["id_proveedor"].values
prov_de_serie = prov_de_sku[sku_de_serie]
lead_obj_serie = dim_proveedor["lead_time_objetivo"].values[prov_de_serie - 1]
confia_serie = _confiabilidad[prov_de_serie - 1]

# Punto de reorden = demanda esperada durante el lead time + stock de seguridad
# Stock de seguridad deliberadamente ajustado: la empresa NO sobre-inventaría.
# Con esto aparecen quiebres reales y el fill rate deja de ser un 99.8% de fantasía.
punto_reorden = np.ceil(lam * lead_obj_serie * 1.0 + 0.5 * np.sqrt(lam * lead_obj_serie)).astype(int)
nivel_objetivo = np.ceil(punto_reorden + lam * 20).astype(int)

existencia = nivel_objetivo.astype(float).copy()
en_transito = np.zeros(n_series)
# Matriz de llegadas programadas: [serie, día]
llegadas = np.zeros((n_series, N_DIAS + 120))

snap_rows = []       # snapshots de inventario
venta_rows = []      # líneas de venta

costo_serie = dim_producto["costo_unitario"].values[sku_de_serie]
precio_serie = dim_producto["precio_lista"].values[sku_de_serie]

for d in range(N_DIAS):
    fecha = fechas[d]

    # 1) Llega lo que estaba en tránsito para hoy
    recibido = llegadas[:, d]
    existencia += recibido
    en_transito -= recibido
    en_transito = np.maximum(en_transito, 0)

    # 2) Demanda del día.
    #    Poisson puro subestima la variabilidad real: en la vida real llega
    #    una constructora y se lleva 40 sacos de golpe. El multiplicador Gamma
    #    mete esa sobredispersión (mezcla Gamma-Poisson) y con ella los picos
    #    que provocan los quiebres.
    sobredisp = rng.gamma(2.2, 1 / 2.2, n_series)
    colapso = np.where(fecha >= FECHA_COLAPSO, colapso_sku[sku_de_serie], 1.0)
    demanda = rng.poisson(lam * mult_dia[d] * sobredisp * colapso)

    # 3) Se vende lo que hay. Lo que falta es quiebre (demanda perdida).
    vendido = np.minimum(demanda, existencia).astype(int)
    existencia -= vendido

    # 4) Snapshot de cierre del día
    snap_rows.append(np.column_stack([
        np.full(n_series, d),
        sku_de_serie + 1,
        bod_de_serie + 1,
        existencia.copy(),
        en_transito.copy(),
        costo_serie,
    ]))

    # 5) Reposición: ¿qué series cayeron bajo el punto de reorden?
    disponible = existencia + en_transito
    reordenar = np.where(disponible < punto_reorden)[0]
    if len(reordenar) > 0:
        cant = nivel_objetivo[reordenar] - disponible[reordenar]
        base = lead_obj_serie[reordenar]
        # Retraso real: depende de la confiabilidad del proveedor
        ruido = rng.exponential((1 - confia_serie[reordenar]) * 12 + 1)
        # ANOMALÍA 2 en acción: el proveedor degradado empieza a fallar
        mask_deg = (prov_de_serie[reordenar] == PROV_DEGRADADO) & (fecha >= FECHA_DEGRADACION)
        ruido = ruido + mask_deg * rng.uniform(10, 25, len(reordenar))
        lt_real = np.clip((base + ruido).astype(int), 1, 110)
        dias_llegada = np.minimum(d + lt_real, N_DIAS + 119)
        np.add.at(llegadas, (reordenar, dias_llegada), cant)
        en_transito[reordenar] += cant

    # 6) Convertir la venta del día en líneas de pedido
    act = np.where(vendido > 0)[0]
    if len(act) > 0:
        cli = rng.integers(1, N_CLIENTES + 1, len(act))
        canal_cli = cli_canal[cli - 1]
        promesa = np.array([dias_promesa_canal[c] for c in canal_cli])
        # Retraso en la entrega: la bodega problema (ANOMALÍA 3) falla más
        p_tarde = np.where(bod_de_serie[act] + 1 == BODEGA_PROBLEMA, 0.30, 0.11)
        tarde = rng.random(len(act)) < p_tarde
        retraso = tarde * rng.integers(1, 8, len(act))
        # Línea completa = se sirvió todo lo que el cliente pidió
        completa = (vendido[act] >= demanda[act])
        # Descuento por canal/volumen
        desc = rng.choice([0.0, 0.03, 0.05, 0.08, 0.12], len(act),
                          p=[0.55, 0.15, 0.14, 0.10, 0.06])
        venta_rows.append(pd.DataFrame({
            "fecha": fecha,
            "id_producto": sku_de_serie[act] + 1,
            "id_bodega": bod_de_serie[act] + 1,
            "id_cliente": cli,
            "unidades": vendido[act],
            "unidades_solicitadas": demanda[act],
            "precio_unitario": np.round(precio_serie[act] * (1 - desc), 2),
            "costo_unitario": costo_serie[act],
            "fecha_prometida": fecha + pd.to_timedelta(promesa, unit="D"),
            "fecha_entrega": fecha + pd.to_timedelta(promesa + retraso, unit="D"),
            "entrega_completa": completa,
        }))

    if d % 250 == 0:
        print(f"   día {d}/{N_DIAS}...")

# --------------------------------------------------------------------
# ARMAR LAS TABLAS DE HECHOS
# --------------------------------------------------------------------
print("Armando tablas de hechos...")

snap = np.vstack(snap_rows)
fact_inventario = pd.DataFrame(snap, columns=[
    "dia_idx", "id_producto", "id_bodega", "existencia", "en_transito", "costo_unitario"])
fact_inventario["fecha"] = fechas[fact_inventario["dia_idx"].astype(int)]
fact_inventario = fact_inventario.drop(columns=["dia_idx"])
fact_inventario["id_producto"] = fact_inventario["id_producto"].astype(int)
fact_inventario["id_bodega"] = fact_inventario["id_bodega"].astype(int)
fact_inventario["existencia"] = fact_inventario["existencia"].astype(int)
fact_inventario["en_transito"] = fact_inventario["en_transito"].astype(int)
fact_inventario["valor_inventario"] = (fact_inventario["existencia"]
                                       * fact_inventario["costo_unitario"]).round(2)
fact_inventario = fact_inventario[["fecha", "id_producto", "id_bodega", "existencia",
                                   "en_transito", "costo_unitario", "valor_inventario"]]

fact_ventas = pd.concat(venta_rows, ignore_index=True)
fact_ventas.insert(0, "id_venta", np.arange(1, len(fact_ventas) + 1))
fact_ventas["venta_neta"] = (fact_ventas["unidades"] * fact_ventas["precio_unitario"]).round(2)
fact_ventas["costo_total"] = (fact_ventas["unidades"] * fact_ventas["costo_unitario"]).round(2)

# --------------------------------------------------------------------
# EXPORTAR
# --------------------------------------------------------------------
print("Escribiendo CSVs...")
tablas = {
    "dim_calendario": dim_calendario,
    "dim_producto": dim_producto,
    "dim_bodega": dim_bodega,
    "dim_cliente": dim_cliente,
    "dim_proveedor": dim_proveedor,
    "fact_ventas": fact_ventas,
    "fact_inventario": fact_inventario,
}
for nombre, df in tablas.items():
    ruta = DIR_SALIDA / f"{nombre}.csv"
    df.to_csv(ruta, index=False, encoding="utf-8")
    print(f"   {nombre:18s} {len(df):>10,} filas")

print(f"\nListo. Archivos en: {DIR_SALIDA}")
print("\nRESUMEN DEL NEGOCIO SIMULADO")
print(f"   Venta total........ Q {fact_ventas['venta_neta'].sum():>16,.0f}")
print(f"   Líneas de venta.... {len(fact_ventas):>18,}")
print(f"   Snapshots.......... {len(fact_inventario):>18,}")
