"""Validazione numeri senza modello/bridge/gioco: sole funzioni pure."""
import unittest
from conversation import validate_args
from tools_bozza import TOOLS_BOZZA


class FiniteArgumentTests(unittest.TestCase):
    def test_real_fleet_schemas_reject_all_nonfinite_intervals(self):
        for name in ['check_line_fleet','adjust_line_fleet']:
            tool=next(t for t in TOOLS_BOZZA if t['name']==name)
            for value in [float('nan'),float('inf'),float('-inf')]:
                with self.subTest(name=name,value=repr(value)):
                    self.assertEqual(validate_args(tool,{'line_id':1,'interval':value}),
                                     ['interval: numero non finito'])

    def test_nested_arrays_report_only_the_invalid_numeric_path(self):
        tool={'input_schema':{'type':'object','properties':{
            'points':{'type':'array','items':{'type':'object','properties':{
                'x':{'type':'number'},'y':{'type':'number'}}}}}}}
        args={'points':[{'x':0,'y':1.25},{'x':float('nan'),'y':2}]}
        self.assertEqual(validate_args(tool,args),['points[1].x: numero non finito'])

    def test_finite_values_large_integers_bounds_and_types_preserved(self):
        tool={'input_schema':{'type':'object','properties':{'value':{'type':'number'}}}}
        for value in [0,-1,1.25,1e308,10**1000]:
            with self.subTest(value_type=type(value).__name__):
                self.assertEqual(validate_args(tool,{'value':value}),[])
        for value in [True,False,'nan']:
            self.assertTrue(validate_args(tool,{'value':value}))
        fleet=next(t for t in TOOLS_BOZZA if t['name']=='check_line_fleet')
        self.assertEqual(validate_args(fleet,{'line_id':1,'interval':60}),[])
        self.assertEqual(validate_args(fleet,{'line_id':1,'interval':3600.0}),[])
        self.assertIn('sotto il minimo',validate_args(fleet,{'line_id':1,'interval':59})[0])
        self.assertIn('sopra il massimo',validate_args(fleet,{'line_id':1,'interval':3601})[0])
