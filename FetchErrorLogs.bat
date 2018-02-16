
FOR /F "tokens=*" %%a in ('findstr "Error(s)" content.txt') do SET OUTPUT=%%a

echo %OUTPUT%

for /F "tokens=1,2 delims=-" %%a in ("%OUTPUT%") do (
   SET VALUE=%%b
)

for /F "tokens=1,2 delims=," %%a in ("%VALUE%") do (
   SET ERROR=%%a
   SET WARNING=%%b
)

echo "No of Errors in Logs are : %Error%"
set "str=%Error: =%"
set "num=1%str%"
set /A num=num
set "num=%num:~1%"
echo ResultError = %num%
echo "No of Warnings in Logs are : %WARNING%"
set "str=%WARNING: =%"
set "num=1%str%"
set /A num=num
set "num=%num:~1%"
echo ResultWarning = %num%
