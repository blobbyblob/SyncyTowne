pushd %~dp0\..
taskkill /F /IM "python.exe"
python server\main.py
popd
