"""File userdata completi: soltanto stringhe fixture, nessun Lua eseguito."""
import unittest
import lua_table


class CompleteLuaParserTests(unittest.TestCase):
    def test_userdata_requires_exact_wrapper_keywords(self):
        for source in ["function other() return {} end", "function data() break {} end",
                       "function data() return {} false"]:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads(source)

    def test_userdata_requires_closing_end(self):
        with self.assertRaises(lua_table.LuaParseError):
            lua_table.loads("function data() return {lastActionId=42}")

    def test_trailing_values_or_statements_rejected(self):
        for source in ["{id=1} {id=2}", "return {id=1} return {id=2}",
                       "function data() return {} end print('fixture')"]:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads(source)

    def test_complete_supported_formats_and_comments_preserved(self):
        for source in ["{id=42,enabled=false}", "return {id=42,enabled=false}",
                       "-- fixture\nfunction data() return {id=42,enabled=false} end -- fine"]:
            with self.subTest(source=source):
                self.assertEqual(lua_table.loads(source), {"id":42,"enabled":False})
