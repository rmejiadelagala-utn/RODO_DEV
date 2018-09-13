
Declare
    nStartIndex number := 1;
    nEndIndex number := 1;
    nLineIndex number := 0;
    vLine varchar2(2000);
    xml_string varchar2(32000):=NULL;
	--RowInsPcio PRECIOS_PM1_ITEM_VER%ROWTYPE --Se necesita una tabla PRECIOS_PM1_ITEM_VER
	
    cursor c_clob is
    select DYNAMIC_DATA  from pm1_item_version  where  (ID, PACKAGE_ID, MAJOR_VERSION_ID) in 
    (select a.ID, a.PACKAGE_ID, MAX(MAJOR_VERSION_ID) as MAX_VERSION  from pm1_item_version a
    where a.PRICING_ITEM_TYPE='**TEF RC flat rate'--Probando sólo con Planes
    group by a.ID, a.PACKAGE_ID) ;

    DYNAMIC_DATA_XML blob;
    
    -------------------------------
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
        dbms_lob.read(p_clob, amount, offset, lc_buffer);
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
	   Dbms_Output.Put_Line('v_Type=' || v_Type);

	   --------                               
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
				   v_Name := Dbms_Xmldom.Getnodevalue(v_Attr_Node);
				Elsif v_Node_Name = 'elementaryType' Then
				   v_ElementaryType := Dbms_Xmldom.Getnodevalue(v_Attr_Node);
				End If;
			 End Loop;
			 Dbms_Output.Put_Line('v_Name=' || v_Name);
			 Dbms_Output.Put_Line('v_ElementaryType=' || v_ElementaryType);
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
				   v_Value := Dbms_Xmldom.Getnodevalue(v_Attr_Node);
				End If;
			  End Loop;
			 Dbms_Output.Put_Line('v_Value=' || v_Value);
		     End If; 
		  --Nuevo agregado 11/09/2018
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
					Dbms_Output.Put_Line('v_SubValue=' || v_SubValue);
					Dbms_Output.Put_Line('v_DimensionName=' || v_DimensionName);
				End If; 
			 
				End Loop;
		   --Fin Nuevo agregado 11/09/2018 ANDUVO!!!!!!!!!!!	
	        End Loop;
		End Loop;
	End;

/*
************************
* Acá INICIA EL PROCESO
************************
*/
BEGIN
    open c_clob;
    loop
       fetch c_clob into DYNAMIC_DATA_XML;
       exit when c_clob%notfound;
	   --Recibe el BLOB y lo carga en la variable xml_string, como un xml
       printout(DYNAMIC_DATA_XML);
	   --Parsea el xml_string 
       Parse_Xml_Example;
    end loop;
    close c_clob;
END;

