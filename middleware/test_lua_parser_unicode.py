"""Unicode ed escape su stringhe sintetiche, senza runtime/file del gioco."""
import unittest
import lua_table


class LuaParserUnicodeTests(unittest.TestCase):
    def test_literal_unicode_roundtrip_preserves_all_codepoints(self):
        values=[chr(195)+chr(169),chr(194)+chr(163),chr(38634),chr(128642),
                'fixture '+chr(195)+chr(169)+' '+chr(38634)]
        for value in values:
            with self.subTest(value=value):
                self.assertEqual(lua_table.loads(lua_table.dumps(value)),value)
        value={values[0]:values[4],'nested':values}
        self.assertEqual(lua_table.loads(lua_table.dumps(value)),value)

    def test_numeric_utf8_bytes_decode_next_to_literal_unicode(self):
        for body in [r'\195\169',r'\xC3\xA9',r'\195\xA9']:
            with self.subTest(body=body):
                source='"'+chr(38634)+body+chr(128642)+'"'
                self.assertEqual(lua_table.loads(source),chr(38634)+chr(233)+chr(128642))

    def test_non_utf8_numeric_bytes_fallback_does_not_change_literal_unicode(self):
        source='"'+chr(38634)+r'\255\000'+'"'
        self.assertEqual(lua_table.loads(source),chr(38634)+chr(255)+chr(0))
        self.assertEqual(lua_table.loads(r'"\255"'),chr(255))

    def test_numeric_escape_requires_valid_byte_and_two_hex_digits(self):
        for body in [r'\256',r'\999',r'\x1',r'\x',r'\xGG',r'\x-1']:
            with self.subTest(body=body):
                with self.assertRaises(lua_table.LuaParseError):
                    lua_table.loads('"'+body+'"')

    def test_control_escapes_and_decimal_digit_boundary_preserved(self):
        self.assertEqual(lua_table.loads(r'"\0651\n\t\r\a\b\f\v\\\"\'"'),
                         'A1\n\t\r\a\b\f\v\\"\'')
        self.assertEqual(lua_table.loads('"a'+r'\z'+' \n\t b"'),'ab')
        self.assertEqual(lua_table.loads(r'"\000\127\255"'),chr(0)+chr(127)+chr(255))

    def test_utf8_runs_separated_by_literal_text_remain_independent(self):
        self.assertEqual(lua_table.loads(r'"\195\169/\226\130\172"'),chr(233)+'/'+chr(8364))
        self.assertEqual(lua_table.loads(r'"\255/\195\169"'),chr(255)+'/'+chr(233))
