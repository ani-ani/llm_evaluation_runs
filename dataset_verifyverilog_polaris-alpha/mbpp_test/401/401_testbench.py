import cocotb
from cocotb.triggers import Timer

def flatten_tuple(nested_tuple):
    flat = 0
    for row in reversed(nested_tuple):
        for num in reversed(row):
            flat = (flat << 5) | num
    return flat

@cocotb.test()
async def test_nested_adder(dut):
    test_cases = [
        # Test 1
        ((
            ((1, 3), (4, 5), (2, 9), (1, 10)),
            ((6, 7), (3, 9), (1, 1), (7, 3)),
            ((7, 10), (7, 14), (3, 10), (8, 13))
        )),
        # Test 2
        ((
            ((2, 4), (5, 6), (3, 10), (2, 11)),
            ((7, 8), (4, 10), (2, 2), (8, 4)),
            ((9, 12), (9, 16), (5, 12), (10, 15))
        )),
        # Test 3
        ((
            ((3, 5), (6, 7), (4, 11), (3, 12)),
            ((8, 9), (5, 11), (3, 3), (9, 5)),
            ((11, 14), (11, 18), (7, 14), (12, 17))
        ))
    ]
    
    passed = 0
    for tup1, tup2, expected in test_cases:
        # Flatten inputs and expected output
        t1_flat = flatten_tuple(tup1)
        t2_flat = flatten_tuple(tup2)
        exp_flat = flatten_tuple(expected)
        
        dut.tuple1_flattened.value = t1_flat
        dut.tuple2_flattened.value = t2_flat
        await Timer(1, units='ns')
        
        if dut.result_flattened.value == exp_flat:
            passed += 1
            dut._log.info(f"PASS: Added tuples correctly")
        else:
            dut._log.error(f"FAIL: Got {dut.result_flattened.value} expected {exp_flat}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")