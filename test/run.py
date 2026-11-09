#!/usr/bin/env python3
"""run.py - Spouštěč testů pro kcdmp-animace (server v Lua 5.4, simulace KCD:MP API)

Použití:
    pip install lupa
    python test/run.py
"""
import os
import sys
import lupa.lua54

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TEST_LUA = os.path.join(ROOT, "test", "test_animace.lua")

print(f"Spoustim testy z {TEST_LUA}...")

lua = lupa.lua54.LuaRuntime(unpack_returned_tuples=True, encoding="utf-8")
g = lua.globals()

# Upravit package.path pro lua
server_dir = os.path.join(ROOT, "server").replace("\\", "/")
test_dir = os.path.join(ROOT, "test").replace("\\", "/")
data_dir = os.path.join(ROOT, "data").replace("\\", "/")

lua.execute(f"""
package.path = package.path .. ";{server_dir}/?.lua;{test_dir}/?.lua;{data_dir}/?.lua"
""")

with open(TEST_LUA, "r", encoding="utf-8") as f:
    code = f.read()

try:
    lua.execute(code)
    print("\n✓ Vsechny testy probehly uspesne.")
except Exception as e:
    print(f"\n✗ Chyba pri vykonavani testu: {e}")
    sys.exit(1)
