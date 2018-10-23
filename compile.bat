pushd "%~dp0\server"
python -m PyInstaller --onefile --console main.py
popd
