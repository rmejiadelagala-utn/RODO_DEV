/*
************************************************************
* PROCESO: PL_PARSER_PM1_ITEM_VERSION
*
* DESCRIPCION: Este proceso se genera para realizar una
*              ACTUALIZACION!!! sobre los precios, de la tabla
*               
************************************************************
*/

SET SERVEROUTPUT ON SIZE 1000000
SET TIMI OFF
SET VERI OFF
SET FEED OFF
SET TERM ON

COLUMN SALIDA1 NEW_VALUE FUERA
VAR SALIDA NUMBER
