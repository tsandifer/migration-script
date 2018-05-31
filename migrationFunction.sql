drop function if exists IsNumeric;
CREATE FUNCTION IsNumeric (val varchar(255)) RETURNS tinyint 
 RETURN val REGEXP '^(-|\\+){0,1}([0-9]+\\.[0-9]*|[0-9]*\\.[0-9]+|[0-9]+)$';

DROP FUNCTION if exists FindNumericValue;
DELIMITER $$
 
CREATE FUNCTION FindNumericValue(val VARCHAR(255)) RETURNS VARCHAR(255)
    DETERMINISTIC
BEGIN
		DECLARE idx INT DEFAULT 0;
		IF ISNULL(val) THEN RETURN NULL; END IF;

		IF LENGTH(val) = 0 THEN RETURN ""; END IF;
 SET idx = LENGTH(val);
		WHILE idx > 0 DO
			IF IsNumeric(SUBSTRING(val,idx,1)) = 0 THEN
				SET val = REPLACE(val,SUBSTRING(val,idx,1),"");
				SET idx = LENGTH(val)+1;
			END IF;
				SET idx = idx - 1;
		END WHILE;
			RETURN val;
END
$$
DELIMITER ;

DROP FUNCTION if exists `formatDate`;
DELIMITER $$
CREATE FUNCTION `formatDate`( dateYy Varchar(10),dateMm Varchar(10),dateDd Varchar(10) ) RETURNS DATE
BEGIN
  IF (FindNumericValue(dateYy)<=0)
  THEN 
    RETURN null;
  END IF;
  
  IF(length(dateYy)<=2) 
  THEN 
   set dateYy=concat('20',FindNumericValue(dateYy));
   END IF;
  
  IF(dateMm is null or dateMm='XX' or dateMm='' or dateMm>12 or dateMm<1)
  THEN 
   set dateMm='01';
   END IF;
 
  IF(dateDd is null or dateDd='XX' or dateDd='' or dateDd>31 or dateDd<1)
  THEN 
   set dateDd='01';
   END IF;
 
 IF((dateMm='01' or dateMm='03' or dateMm='05' or dateMm='07' or dateMm='08' or dateMm='10' or dateMm='12') and dateDd>31)
 THEN 
  set dateDd='31';
  END IF;
 
  IF((dateMm='04' or dateMm='06' or dateMm='09' or dateMm='11') and dateDd>30)
 THEN 
  set dateDd='30';
  END IF;
  
 IF((dateMm='02') and dateDd>29)
 THEN 
  set dateDd='28';
  END IF;
 
  RETURN date(concat (dateYy,'-',dateMm,'-',dateDd),'%y-%m-%d');
END$$
DELIMITER ;

DROP FUNCTION if exists `digits`;
DELIMITER $$
CREATE FUNCTION `digits`( str CHAR(32) ) RETURNS char(32) CHARSET utf8
BEGIN
  DECLARE i, len SMALLINT DEFAULT 1;
  DECLARE ret CHAR(32) DEFAULT '';
  DECLARE c CHAR(1);
  DECLARE pos SMALLINT;
  DECLARE after_p CHAR(20);
  IF str IS NULL
  THEN 
    RETURN "";
  END IF;
  SET len = CHAR_LENGTH( str );
  l:REPEAT
    BEGIN
      SET c = MID( str, i, 1 );
      IF c BETWEEN '0' AND '9' THEN 
        SET ret=CONCAT(ret,c);
      ELSEIF c = '.' OR c = ',' THEN
		IF c = '.' THEN
			SET pos=INSTR(str, '.' );
            SET after_p=MID(str,pos,pos+2);
            SET ret=CONCAT(FindNumericValue(ret),'.',FindNumericValue(after_p));
            LEAVE l;
		ELSEIF c = ',' THEN 
			SET pos=INSTR(str, ',');
            SET after_p=MID(str,pos,pos+2);
            SET ret=CONCAT(FindNumericValue(ret),'.',FindNumericValue(after_p));
            LEAVE l;
		END IF;
      END IF;
      
      SET i = i + 1;
      
    END;
  UNTIL i > len END REPEAT;
  RETURN ret;
END$$
DELIMITER ;
