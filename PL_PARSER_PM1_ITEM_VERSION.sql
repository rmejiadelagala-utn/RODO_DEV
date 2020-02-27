/*
************************************************************
* PROCESO: PL_PARSER_PM1_ITEM_VERSION
*
* DESCRIPCION: Este proceso se genera para realizar una
*              ACTUALIZACION!!! sobre los precios, de la tabla
*               PM1_ITEM_VERSION en TFA_PRECIOS_ITEM_VERSION
************************************************************
*/

SET SERVEROUTPUT ON SIZE 1000000
SET TIMI OFF
SET VERI OFF
SET FEED OFF
SET TERM ON

COLUMN SALIDA1 NEW_VALUE FUERA
VAR SALIDA NUMBER

Declare
    nStartIndex number := 1;
    nEndIndex number := 1;
    nLineIndex number := 0;
    vLine varchar2(2000):=NULL;
    xml_string varchar2(32767):=NULL;
    RowInsPcio TFA_PRECIOS_ITEM_VERSION%ROWTYPE :=NULL; --Se necesita una tabla TMP_PRECIOS_ITEM_VERSION
    checkingTablaTmp  NUMBER :=0;

    cursor c_clob is
    select PACKAGE_ID,DYNAMIC_DATA  from pm1_item_version  where  (ID, PACKAGE_ID, MAJOR_VERSION_ID) in
    (select a.ID, a.PACKAGE_ID, MAX(MAJOR_VERSION_ID) as MAX_VERSION  from pm1_item_version a
    where a.PRICING_ITEM_TYPE in
    ('**TEF Flat or Percentage RC Discount',
    '**TEF Flat or Percentage RC Discount for component',
    '**TEF RC Insurance flat rate', -- lo de insurance lo manejamos aparte por la Gama.
    '**TEF RC based on Package ID',
    '**TEF RC based on Package ID for WRLS',
    '**TEF RC based on Speed and Central group ID',
    '**TEF RC flat rate',
    '**TEF RC flat rate for IPTV',
    '**TEF RC flat rate for OTT',
    '**TEF RC flat rate for multiple components'
    ) --con esto estoy acotando unas offertas especificas, la idea es crear una tabla con ofertas a actualizar.
    and id in (select item_cd from csm_offer_item where package_cd in (  
                select offer from bl1_version_details 
                where offer_effective_date='19-Oct-2019' and release_seq_no=264330 and cycle_code=1))
    and id in (select id from tfa_precios_item_version where valid_to='18-Oct-2019')
    group by a.ID, a.PACKAGE_ID) ;

    DYNAMIC_DATA_XML blob;
    vPACKAGE_ID NUMBER;

    ---------------------------------------------------------------------------------------
    /* 
        
    */
    procedure printout (p_clob in out nocopy blob ) is
      offset number := 1;
      amount number := 32767;
      len    number := dbms_lob.getlength(p_clob);
      lc_buffer varchar2(32767); --buffer temporal en donde voy guardando partes del xml.
      i pls_integer := 1;
    begin
      if ( dbms_lob.isopen(p_clob) != 1 ) then
        dbms_lob.open(p_clob, 0);
      end if;
      amount := 2000;--instr(p_clob, chr(10), offset);
      xml_string:=NULL;
      while ( offset < len )
      loop
        dbms_lob.read(p_clob, amount, offset, lc_buffer); --la función read solo se lee hasta 2000 char, por eso el buffer
        xml_string :=xml_string||hex_to_ascii(lc_buffer);
        offset := offset + amount;

      end loop;
--        dbms_output.put_line(xml_string);
      if ( dbms_lob.isopen(p_clob) = 1 ) then
        dbms_lob.close(p_clob);
      end if;
    exception
      when others then
      BEGIN
            vLine:=  substr(hex_to_ascii(Dbms_Lob.Substr(p_clob,   2000,1)) --param1
                    ,INSTR(hex_to_ascii(Dbms_Lob.Substr(p_clob,   2000,1)),'Attribute name="Charge code" elementaryType="Charge code" auxiliaryType="Charge codes"><Value value="')+101 --param2
                    ,INSTR(hex_to_ascii(Dbms_Lob.Substr(p_clob,   2000,INSTR(hex_to_ascii(Dbms_Lob.Substr(p_clob,2000,1)),'Attribute name="Charge code" elementaryType="Charge code" auxiliaryType="Charge codes"><Value value="')+101)),'"')-1); --param3
            dbms_output.put_line('Error : '||vLine||'  '||sqlerrm);
      end;
    end printout;

    ---------------------------
    Procedure Parse_Xml_Example  is
       p              Dbms_Xmlparser.Parser;
       v_Doc          Dbms_Xmldom.Domdocument;
       v_Root_Element Dbms_Xmldom.Domelement;
       v_Child_Nodes  Dbms_Xmldom.Domnodelist;
       v_Child_Node   Dbms_Xmldom.Domnode;
       v_SubChild_Nodes  Dbms_Xmldom.Domnodelist;
       v_SubChild_Node Dbms_Xmldom.Domnode;
       v_Text_Node    Dbms_Xmldom.Domnode;
       v_Param_Nodes    Dbms_Xmldom.Domnodelist;
       v_Param_Node     Dbms_Xmldom.Domnode;
       ---
    --   v_Xml_Data Varchar2(4000);
       v_Type     Varchar2(100);
       v_Version    Varchar2(100);
       v_Location Varchar2(255);
       v_Name    Varchar2(200);
       v_ElementaryType    Varchar2(100);
       v_Value      Varchar2(100);
       v_SubValue   Varchar2(100);
       v_DimensionName Varchar2(50);
       v_Hiredate Date;
       v_Mrg      Number;
       v_Sal      Number;
       --
       v_Attr_Nodes     Dbms_Xmldom.Domnamednodemap;
       v_Attr_Node      Dbms_Xmldom.Domnode;
       v_SubAttr_Nodes  Dbms_Xmldom.Domnamednodemap;
       v_SubAttr_Node   Dbms_Xmldom.Domnode;
       v_Attribute_Name Varchar2(50);
       v_Node_Name      Varchar2(100);
       v_Node_Value     Dbms_Xmldom.Domnode;
       v_largo number;
       v_NewLine varchar2(4000) :=NULL;
       v_NewLineTotal varchar2(4000) :=NULL;
       v_NewLine2 varchar2(4000) :=NULL;
       v_Precio Varchar2(50);
       v_ID Varchar2(50);
       v_Charge_code Varchar2(100);
       v_Speed Varchar2(50);
        v_CentralGroup Varchar2(50);
        v_ValidoDesde DATE;
        v_ProductType Varchar2(4);



    Begin
       -- Note text contains no <?xml version="1"?>
       --length(<?xml version="1.0" encoding="ISO-8859-15"?>)=45
       --length (<Scales></Scales>) =17
        --Entonces 62=45+17
       v_largo:=length(xml_string)-62; -- le saco la primer parte y la ultima parte, dejando solo el xml puro.
       xml_string:=substr(xml_string,45,v_largo);
       -- Create XML Parser.
       p := Dbms_Xmlparser.Newparser;
       Dbms_Xmlparser.Setvalidationmode(p,False);
       -- Parse XML into DOM object
       Dbms_Xmlparser.Parsebuffer(p,xml_string);
       -- Document
       v_Doc := Dbms_Xmlparser.Getdocument(p);
       -- Root element (<department>)
       v_Root_Element := Dbms_Xmldom.Getdocumentelement(v_Doc);
       -- Get attribute value
       v_Type   := Dbms_Xmldom.Getattribute(v_Root_Element,'type');
       ---------
--       Dbms_Output.Put_Line('v_Type=' || v_Type);

       --------
          v_ID:=NULL;
          v_Charge_code:=NULL;
          v_Speed:=NULL;
          v_CentralGroup:=NULL;
          v_Precio:=NULL;
          RowInsPcio:=NULL;
          
--         Busco la nueva fecha de vigencia de la oferta.
          BEGIN
                Select MAX(RATE_EFFECTIVE_DATE) 
                INTO v_ValidoDesde
                from BL1_VERSION_DETAILS WHERE offer=vPACKAGE_ID;
                
                IF v_ValidoDesde is null
                then
                v_ValidoDesde := to_date('01012000','DDMMYYYY');
                end if;
                
          EXCEPTION
                WHEN NO_DATA_FOUND THEN
                  v_ValidoDesde := to_date('01012000','DDMMYYYY');
         END;
         
--         Busco el product_type
          BEGIN
                Select distinct PRODUCT_TYPE
                INTO v_ProductType
                from CSM_OFFER 
                WHERE SOC_CD in (Select soc_cd from csm_offer_item 
                                    where package_cd=vPACKAGE_ID);
                
          EXCEPTION
                WHEN OTHERS THEN
                  DBMS_OUTPUT.PUT_LINE(SUBSTR('ERROR: '||SQLERRM,1,1200));
         END;            


--          Busco el precio y los parametros.
       -- Node list (Attribute) of v_Root_Element (Dbms_xmldom.Domnodelist)
       v_Param_Nodes := Dbms_Xmldom.Getelementsbytagname(v_Root_Element,'Attribute');
       For j In 0 .. Dbms_Xmldom.Getlength(v_Param_Nodes) Loop

          v_Param_Node := Dbms_Xmldom.Item(v_Param_Nodes,j);
          -- Attribute List (Dbms_xmldom.Domnamednodemap)
          v_Attr_Nodes := Dbms_Xmldom.Getattributes(v_Param_Node);
          --
          If (Dbms_Xmldom.Isnull(v_Attr_Nodes) = False) Then
             For i In 0 .. Dbms_Xmldom.Getlength(v_Attr_Nodes) - 1 Loop
                v_Attr_Node := Dbms_Xmldom.Item(v_Attr_Nodes,i);
                v_Node_Name := Dbms_Xmldom.Getnodename(v_Attr_Node);
                --
                If v_Node_Name = 'name' Then
                   v_Name := Dbms_Xmldom.Getnodevalue(v_Attr_Node); --Obtengo el name
                Elsif v_Node_Name = 'elementaryType' Then
                   v_ElementaryType := Dbms_Xmldom.Getnodevalue(v_Attr_Node);
                End If;
             End Loop;
--             Dbms_Output.Put_Line('v_Name=' || v_Name);
--             Dbms_Output.Put_Line('v_ElementaryType=' || v_ElementaryType);
          End If;
          ----
          -- Child nodes of Params node.
          --
          v_Child_Nodes := Dbms_Xmldom.Getchildnodes(v_Param_Node);
          --
            For i In 0 .. Dbms_Xmldom.Getlength(v_Child_Nodes) - 1 Loop
             -- <value>
             v_Child_Node := Dbms_Xmldom.Item(v_Child_Nodes,i);
             v_Attr_Nodes := Dbms_Xmldom.Getattributes(v_Child_Node);
          --
             If (Dbms_Xmldom.Isnull(v_Attr_Nodes) = False) Then
              For i In 0 .. Dbms_Xmldom.Getlength(v_Attr_Nodes) - 1 Loop
                v_Attr_Node := Dbms_Xmldom.Item(v_Attr_Nodes,i);
                v_Node_Name := Dbms_Xmldom.Getnodename(v_Attr_Node);
                --
                If v_Node_Name = 'value' Then
                   v_Value := Dbms_Xmldom.Getnodevalue(v_Attr_Node); --aca obtengo el value
                End If;
              End Loop;
--              Dbms_Output.Put_Line('v_Value=' || v_Value);
              -- hasta acá ya tengo el name, elementaryType y el value, para uno solo.
                If v_Name = 'Item ID' then
                    v_ID:=v_Value;  --Guardo el ID
                Elsif v_Name ='Rate' or v_Name ='Discount value'  then
                    v_Precio:=v_Value;  -- Guardo el precio
--                    v_NewLine:=v_NewLine||'|'||v_Value;
                ELSIF v_Name = 'Charge code' then
                    v_Charge_code:=v_Value;  --Guardo el charge_code
                ELSIF (v_Name = 'Rate table' OR v_Name= 'Rate by device gama') then
                --Nuevo agregado 11/09/2018
                    v_Precio:=v_Value;
                    v_SubChild_Nodes:= Dbms_Xmldom.Getchildnodes(v_Child_Node);

                    For i In 0 .. Dbms_Xmldom.Getlength(v_SubChild_Nodes) - 1 Loop
                     -- <DimensionKey>
                    v_SubChild_Node := Dbms_Xmldom.Item(v_SubChild_Nodes,i);
                    v_SubAttr_Nodes := Dbms_Xmldom.Getattributes(v_SubChild_Node);

                    If (Dbms_Xmldom.Isnull(v_SubAttr_Nodes) = False) Then
                        For i In 0 .. Dbms_Xmldom.Getlength(v_SubAttr_Nodes) - 1 Loop
                        v_SubAttr_Node := Dbms_Xmldom.Item(v_SubAttr_Nodes,i);
                        v_Node_Name := Dbms_Xmldom.Getnodename(v_SubAttr_Node);
                    --
                        If v_Node_Name = 'value' Then
                            v_SubValue := Dbms_Xmldom.Getnodevalue(v_SubAttr_Node);
                        Elsif v_Node_Name = 'dimensionName' Then
                           v_DimensionName := Dbms_Xmldom.Getnodevalue(v_SubAttr_Node);
                        End If;
                        End Loop;
--                        Dbms_Output.Put_Line('v_SubValue=' || v_SubValue);
--                        Dbms_Output.Put_Line('v_DimensionName=' || v_DimensionName);
                        if (v_DimensionName = 'Speed' OR v_DimensionName = 'Package ID')  then
                            v_Speed:=v_SubValue;
                        elsif (v_DimensionName = 'Central group ID' OR v_DimensionName = 'Device gama type'  ) then
                            v_CentralGroup:=v_SubValue;
                        end if;

                    End If;

                    End Loop;
                    v_NewLineTotal:=v_ID||'|'||v_Charge_code||'|'||v_Speed||'|'||v_CentralGroup||'|'||v_Precio||'|'||v_Type||'|'|| v_ValidoDesde||'|'||v_ProductType;
                    Dbms_Output.Put_Line(v_NewLineTotal);
                   BEGIN
                    RowInsPcio.ID               := v_ID;
                    RowInsPcio.CHARGE_CODE      := v_Charge_code;
                    RowInsPcio.SPEED            := TO_NUMBER(v_Speed,'99999999.9900');
                    RowInsPcio.CENTRAL_GROUP_ID := v_CentralGroup;
                    RowInsPcio.PRECIO           := TO_NUMBER(v_Precio,'99999999.9900');
                    RowInsPcio.PRICING_ITEM_TYPE:= v_Type;
                    RowInsPcio.VALID_FROM       :=v_ValidoDesde;
                    RowInsPcio.PRODUCT_TYPE     := v_ProductType;
                    

                    INSERT INTO TFA_PRECIOS_ITEM_VERSION
                    VALUES RowInsPcio;
                    COMMIT;

                   EXCEPTION
                    when others then
                               DBMS_OUTPUT.PUT_LINE(SUBSTR('ERROR: '||v_NewLineTotal||' ',1,200));
                     END;


                --Fin Nuevo agregado 11/09/2018 ANDUVO!!!!!!!!!!!
                End If;

             End If;

            End Loop;
        End Loop;
        v_NewLineTotal:=v_ID||'|'||v_Charge_code||'|'||v_Speed||'|'||v_CentralGroup||'|'||v_Precio||'|'||v_Type||'|'|| v_ValidoDesde||'|'||v_ProductType;
        Dbms_Output.Put_Line(v_NewLineTotal);
                 BEGIN
                    RowInsPcio.ID                := v_ID;
                    RowInsPcio.CHARGE_CODE       := v_Charge_code;
                    RowInsPcio.SPEED             := TO_NUMBER(v_Speed,'99999999.9900');
                    RowInsPcio.CENTRAL_GROUP_ID  := v_CentralGroup;
                    RowInsPcio.PRECIO            := TO_NUMBER(v_Precio,'99999999.9900');
                    RowInsPcio.PRICING_ITEM_TYPE := v_Type;
                    RowInsPcio.VALID_FROM        :=v_ValidoDesde;
                    RowInsPcio.PRODUCT_TYPE      := v_ProductType;

                    INSERT INTO TFA_PRECIOS_ITEM_VERSION
                    VALUES RowInsPcio;
                    COMMIT;

                   EXCEPTION
                    when others then
                               DBMS_OUTPUT.PUT_LINE(SUBSTR('ERROR: '||v_NewLineTotal||' '||SQLERRM,1,1200));
                     END;

           COMMIT;

    End;

/*
************************
* Acá INICIA EL PROCESO
************************
*/
BEGIN

     open c_clob;
    loop
       fetch c_clob into vPACKAGE_ID,DYNAMIC_DATA_XML;
       exit when c_clob%notfound;
       --Recibe el BLOB y lo carga en la variable xml_string, como un xml
       printout(DYNAMIC_DATA_XML);
       --Parsea el xml_string
       Parse_Xml_Example;
    end loop;
    close c_clob;
EXCEPTION
    WHEN OTHERS THEN
    DBMS_OUTPUT.PUT_LINE(xml_string);
END;
/

SET TERM OFF
SELECT :SALIDA AS SALIDA1 FROM DUAL;
EXIT &FUERA
