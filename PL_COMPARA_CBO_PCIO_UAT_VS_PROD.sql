SET SERVEROUTPUT ON SIZE 1000000
SET TIMI OFF
SET VERI OFF
SET FEED OFF
SET TERM ON

COLUMN SALIDA1 NEW_VALUE FUERA
VAR SALIDA NUMBER

Declare
	vID PM1_ITEM_VERSION.ID%TYPE;
	vPackage PM1_ITEM_VERSION.PACKAGE_ID%TYPE;
	vMaxVersion PM1_ITEM_VERSION.MAJOR_VERSION_ID%TYPE;
	vLine VARCHAR2(200);
	vTabla VARCHAR2(200);
	vDif number(5);
	ContProc  NUMBER(10) := 0;
	ContErr  NUMBER(10) := 0;
	ContCbios NUMBER(10) := 0;

cursor offer_uat4 is
select ID, PACKAGE_ID, MAX(MAJOR_VERSION_ID) as MAX_VERSION  from  pm1_item_version@apb_to_uat4
    where PRICING_ITEM_TYPE in
    ('**TEF Flat or Percentage RC Discount',
    '**TEF Flat or Percentage RC Discount for component',
    '**TEF RC Insurance flat rate', -- lo de insurance lo manejamos aparte por la Gama.
    '**TEF RC based on Package ID',
    '**TEF RC based on Package ID for WRLS',
    '**TEF RC based on Speed and Central group ID',
    '**TEF RC flat rate',
    '**TEF RC flat rate for IPTV',
    '**TEF RC flat rate for OTT',
    '**TEF RC flat rate for multiple components',
    '**TEF RC based on Type and Number of Units for CSB',
    '**TEF RC based on Type for OTT'
    ) 
    group by ID, PACKAGE_ID;


TYPE fetch_offer_uat IS TABLE OF offer_uat4%ROWTYPE;
RowUAT fetch_offer_uat;    

BEGIN
  :SALIDA :=0;
  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Control Cambio de Precios UAT vs PROD: '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss'));
  DBMS_OUTPUT.PUT_LINE('---------------------------------------------------------------');

    
  vTabla := 'Open Cursor offer_uat4';
  OPEN offer_uat4;
  FETCH offer_uat4 BULK COLLECT INTO RowUAT;
  CLOSE offer_uat4;
  
  DBMS_OUTPUT.PUT_LINE('ID_UAT|PACKAGE_ID_UAT|MAX_VERSION_UAT|ID_PROD|PACKAGE_ID_PROD|MAX_VERSION_PROD|DIFERENCIA');
  
  FOR i IN 1..RowUAT.COUNT LOOP
    
	ContProc := ContProc + 1;
	--inicializo las variables por las dudas
	vID:=null;
	vPackage:=null;
	vMaxVersion:=null;
	vDif := null;
	
   BEGIN
    vTabla := 'PM1_ITEM_VERSION PROD (S)';
	select ID, PACKAGE_ID, MAX(MAJOR_VERSION_ID) as MAX_VERSION
	into vID,vPackage, vMaxVersion
	from pm1_item_version
	where ID=RowUAT(i).ID
	and PACKAGE_ID= RowUAT(i).PACKAGE_ID
	group by ID,PACKAGE_ID;
	
	vDif:=RowUAT(i).MAX_VERSION-vMaxVersion;
	
	IF(vDif !=0) THEN 
	ContCbios := ContCbios + 1;
	vLine:=RowUAT(i).ID||'|'||RowUAT(i).PACKAGE_ID||'|'||RowUAT(i).MAX_VERSION||'|'||vID||'|'||vPackage||'|'||vMaxVersion||'|'||vDif;
	DBMS_OUTPUT.PUT_LINE(vLine);
	END IF;
	
   EXCEPTION
    when others then
         DBMS_OUTPUT.PUT_LINE(SUBSTR('ERROR: '||vTabla||' '||RowUAT(i).ID ||' '||SQLERRM,1,200));
         ContErr:=ContErr+1;
         :SALIDA:=2;
   END;
  END LOOP;

  DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Ofertas Procesadas                                               : '||ContProc);
  DBMS_OUTPUT.PUT_LINE('Ofertas Cambiaron Pcio                                           : '||ContCbios);
  DBMS_OUTPUT.PUT_LINE('Cantidad de Errores                                              : '||ContErr );
  DBMS_OUTPUT.PUT_LINE('-----------------------------------------------------------------------------');
  DBMS_OUTPUT.PUT_LINE('Proceso Finalizado: '||to_char(sysdate,'dd/mm/yyyy hh24:mi:ss'));


EXCEPTION
    WHEN OTHERS THEN
        DBMS_OUTPUT.PUT_LINE(SUBSTR('ERROR: '||vTabla||'  '||SQLERRM,1,200));
        :SALIDA:=1;
 END;
 /

SET TERM OFF
SELECT :SALIDA AS SALIDA1 FROM DUAL;
EXIT &FUERA



