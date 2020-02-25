IF OBJECT_ID('tempdb..#X') IS NOT NULL DROP TABLE #X
IF OBJECT_ID('tempdb..#Y') IS NOT NULL DROP TABLE #Y
IF OBJECT_ID('tempdb..#XY') IS NOT NULL DROP TABLE #XY
IF OBJECT_ID('tempdb..#2RESOLVE') IS NOT NULL DROP TABLE #2RESOLVE
IF OBJECT_ID('tempdb..#2TMPDB') IS NOT NULL DROP TABLE #2TMPDB

SELECT value INTO #X FROM string_split('5,10,15,20,25,30,35,40,45,50,55,60,65,70,75,80,85,90,95',',')
SELECT value INTO #Y FROM string_split('30,60,90,180,270,360,540',',')

SELECT * INTO #XY FROM
(
SELECT 1 as Col1,2 as Col2,3 as Col3,4 as Col4,5 as Col5,6 as Col6, 7 as Col7,8 as Col8,9 as Col9,10 as Col10,11 as Col11,12 as Col12,13 as Col13,14 as Col14,15 as Col15,16 as Col16,17 as Col17,18 as Col18,19 as Col19 UNION
SELECT 4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22 UNION
SELECT 7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25 UNION
SELECT 11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29 UNION
SELECT 14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32 UNION
SELECT 17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35 UNION
SELECT 21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39
) zzz

-- here is the X,Y cooronates to interpolates

SELECT * INTO #2RESOLVE
FROM
(
SELECT 17 as X, 33 as Y UNION -- 3.66257701
SELECT 19, 44 UNION -- 5.11648115
SELECT 24, 52 UNION -- 6.94579056
SELECT 34, 63 UNION -- 10.12166594
SELECT 41, 69 UNION -- 12.15974548
SELECT 56, 74 -- 15.67988759
) yyy

DECLARE @xVa nvarchar(max) = (SELECT * FROM #X FOR JSON AUTO);
DECLARE @yVa nvarchar(max) = (SELECT * FROM #Y FOR JSON AUTO);

DECLARE @RSVxa nvarchar(max) = (SELECT X FROM #2RESOLVE FOR JSON AUTO);
DECLARE @RSVya nvarchar(max) = (SELECT Y FROM #2RESOLVE FOR JSON AUTO);

DECLARE @FINALOUTPUT nvarchar(max);
DECLARE @XOUTPUT nvarchar(max);
DECLARE @YOUTPUT nvarchar(max);

EXECUTE sp_execute_external_script @language = N'Python'
, @script = N'
import sys
from scipy import interpolate
import pandas as pd
import numpy

xV1 = pd.read_json(xValues)
yVl = pd.read_json(yValues)
xx = interpolate.interp2d(xV1,yVl,XY,kind=''cubic'' )
# loop all the #2RESOLVE X,Y to interpolates
rsxVl = pd.read_json(RSxValues, orient = ''records'')
rsyVl = pd.read_json(RSyValues, orient = ''records'')
XYResult = list()

for i in range(len(rsxVl["X"])):
	XYResult.append(xx(rsxVl["X"][i], rsyVl["Y"][i])[0])

xyoutput = pd.DataFrame(XYResult).to_json(orient="split")
xoutput = pd.DataFrame(rsxVl).to_json(orient="split")
youtput = pd.DataFrame(rsyVl).to_json(orient="split")
'
,@input_data_1 = N'SELECT * FROM #XY'
,@input_data_1_name = N'XY'
,@params = N'@xValues nvarchar(max), @yValues nvarchar(max), @RSxValues nvarchar(max), @RSyValues nvarchar(max), @xyoutput nvarchar(max) output, @xoutput nvarchar(max) output, @youtput nvarchar(max) output'
,@xValues = @xVa
,@yValues = @yVa
,@RSxValues = @RSVxa
,@RSyValues = @RSVya
,@xyoutput = @FINALOUTPUT OUTPUT
,@xoutput = @XOUTPUT OUTPUT
,@youtput = @YOUTPUT OUTPUT;
with tpdb(X, Y, XY) as(
	SELECT REPLACE(REPLACE(t1.xv, '[', ''), ']', '') X, REPLACE(REPLACE(t2.yv, '[', ''), ']', '') Y, REPLACE(REPLACE(t0.fv, '[', ''), ']', '') XY FROM (select [key] fk , value fv from OPENJSON(@FINALOUTPUT, '$."data"')) t0 LEFT JOIN (SELECT [key] xk , value xv FROM OPENJSON(@XOUTPUT, '$."data"')) t1 ON t0.fk = t1.xk LEFT JOIN (SELECT [key] yk , value yv from OPENJSON(@YOUTPUT, '$."data"')) t2 ON t2.yk = t0.fk
)select * into #2TMPDB from tpdb;
--you view data by using keyword "where"  
SELECT * from #2TMPDB --WHERE X = 24 AND Y = 52;
