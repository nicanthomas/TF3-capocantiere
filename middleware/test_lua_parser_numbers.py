"""Numeri e separatori letterali su sole stringhe, nessun runtime Lua."""
import unittest
import lua_table


class LuaParserNumbersTests(unittest.TestCase):
    def test_decimal_integer_digits_preserved_without_float_roundtrip(self):
        for value in [2**53+1,2**63-1,-(2**53+1),-(2**63)]:
            with self.subTest(value=value):
                result=lua_table.loads("{id="+str(value)+"}")["id"]
                self.assertIs(type(result),int)
                self.assertEqual(result,value)

    def test_separated_minus_only_accepts_numeric_literal(self):
        for source in ["- true","- false","- nil","- {}","- 'fixture'"]:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads(source)

    def test_nonfinite_decimal_literals_rejected(self):
        for source in ["1e999","-1e999","{id=1e999}"]:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads(source)

    def test_table_fields_require_separator(self):
        for source in ["{a=1 b=2}","{1 2}","{a={1} b=false}"]:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads(source)

    def test_valid_numeric_forms_and_nested_separators_preserved(self):
        self.assertEqual(lua_table.loads("{a=- 1.25; b=0x10,c={1,2;3,};d=1e2}"),
                         {"a":-1.25,"b":16,"c":[1,2,3],"d":100.0})
        self.assertEqual(lua_table.loads("- 42"),-42)
        self.assertEqual(lua_table.loads("-0x10"),-16)
        self.assertEqual(lua_table.loads("1e-999"),0.0)
