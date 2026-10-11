"""Terminatori Lua su sole stringhe sintetiche, senza filesystem del gioco."""
import unittest
import lua_table


class LuaLineEndingTests(unittest.TestCase):
    def test_long_string_first_line_break_ignored_for_all_endings(self):
        for ending in ['\n','\r','\r\n','\n\r']:
            with self.subTest(ending=repr(ending)):
                self.assertEqual(lua_table.loads('[=['+ending+'fixture]=]'),'fixture')
                self.assertEqual(lua_table.loads('[['+ending+ending+'fixture]]'),'\nfixture')

    def test_long_string_line_breaks_normalized_to_single_lf(self):
        source='[[a\r\nb\rc\n\rd\ne]]'
        self.assertEqual(lua_table.loads(source),'a\nb\nc\nd\ne')
        self.assertEqual(lua_table.loads('[==[a\r\r\nb]==]'),'a\n\nb')

    def test_backslash_line_break_normalizes_and_consumes_one_pair(self):
        for ending in ['\n','\r','\r\n','\n\r']:
            with self.subTest(ending=repr(ending)):
                self.assertEqual(lua_table.loads('"a'+chr(92)+ending+'b"'),'a\nb')

    def test_long_literals_preserve_unicode_backslashes_and_bracket_levels(self):
        body=chr(38634)+r'\195\169 [[nested]] '+chr(195)+chr(169)
        self.assertEqual(lua_table.loads('[=['+body+']=]'),body)
        values=['fixture\r\nline',chr(195)+chr(169)+'\n'+chr(38634)]
        self.assertEqual(lua_table.loads(lua_table.dumps(values)),values)
