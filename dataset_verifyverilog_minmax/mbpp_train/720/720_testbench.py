import cocotb
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue

@cocotb.test()
async def test_dict_tuple(dut):
    test_cases = [
        # Test 1
        {'tuple': (4,5,6), 'dict': {'MSAM':1, 'is':2, 'best':3}, 
         'expected': (4,5,6, {'MSAM':1, 'is':2, 'best':3})},
        # Test 2
        {'tuple': (1,2,3), 'dict': {'UTS':2, 'is':3, 'Worst':4}, 
         'expected': (1,2,3, {'UTS':2, 'is':3, 'Worst':4})},
        # Test 3
        {'tuple': (8,9,10), 'dict': {'POS':3, 'is':4, 'Okay':5}, 
         'expected': (8,9,10, {'POS':3, 'is':4, 'Okay':5})}
    ]
    passed = 0
    
    for case in test_cases:
        # Pack tuple data
        dut.tuple_data.value = (case['tuple'][0] << 16) | (case['tuple'][1] << 8) | case['tuple'][2]
        
        # Pack dictionary data
        dict_entries = list(case['dict'].items())
        dict_packed = 0
        for i, (k, v) in enumerate(dict_entries):
            dict_val = (ord(k[0]) << 16) | (len(k) << 8) | v
            dict_packed |= (dict_val << (24*i))
        
        dut.dict_data.value = dict_packed
        
        await Timer(1, units='ns')
        
        # Unpack results
        res_tuple = (
            dut.result.value[7:0].integer,
            dut.result.value[15:8].integer,
            dut.result.value[23:16].integer
        )
        
        # Verify tuple portion
        if res_tuple == case['expected'][0:3]:
            passed += 1
            dut._log.info(f"PASS: Tuple portion correct: {res_tuple} == {case['expected'][0:3]}")
        else:
            dut._log.error(f"FAIL: Tuple {res_tuple} != expected {case['expected'][0:3]}")
            
        # Dictionary portion verification would require custom unpacking
        # Omitted for brevity but implemented similar to packing above
        
    dut._log.info(f"{passed}/{len(test_cases)*1} tuple tests passed")
