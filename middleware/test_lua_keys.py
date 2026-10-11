"""Chiavi del subset userdata: niente collisioni bool/int o errori Python raw."""
from pathlib import Path
import tempfile
import unittest
import lua_table


class LuaTableKeyTests(unittest.TestCase):
    def test_boolean_keys_refused_instead_of_collapsing_into_integer_indices(self):
        for source in ['{[true]="x"}','{[false]="x"}',
                       '{[true]="x",[1]="y"}','{[false]="x",[0]="y"}']:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError): lua_table.loads(source)

    def test_nil_and_table_keys_refused_with_parser_error(self):
        for source in ['{[nil]="x"}','{[{}]="x"}','{[{1}]="x"}']:
            with self.subTest(source=source):
                with self.assertRaises(lua_table.LuaParseError): lua_table.loads(source)

    def test_boolean_key_serialization_fails_before_any_file_change(self):
        with tempfile.TemporaryDirectory() as directory:
            path=Path(directory)/'state.lua'
            path.write_bytes(b'original fixture')
            for key in (True,False):
                with self.subTest(key=key):
                    with self.assertRaises(ValueError): lua_table.dumps({key:'x'})
                    with self.assertRaises(ValueError): lua_table.save_userdata(str(path),{key:'x'})
                    self.assertEqual(path.read_bytes(),b'original fixture')
                    self.assertEqual([p.name for p in Path(directory).iterdir()],['state.lua'])

    def test_supported_numeric_and_string_keys_and_boolean_values_preserved(self):
        self.assertEqual(lua_table.loads('{[1]=false,[2]=true}'),[False,True])
        self.assertEqual(lua_table.loads('{[1.5]="x",[0]="zero",name=false}'),
                         {1.5:'x',0:'zero','name':False})
        value={1:'integer','1':'string','return':False,3:True}
        self.assertEqual(lua_table.loads(lua_table.dumps(value)),value)
