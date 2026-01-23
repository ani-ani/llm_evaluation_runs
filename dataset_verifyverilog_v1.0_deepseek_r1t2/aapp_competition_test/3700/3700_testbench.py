import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_ways_to_choose(dut):
    test_cases = [
        (8, 5, 2),
        (8, 15, 1),
        (7, 20, 0),
        (1000000000000, 1000000000001, 500000000000),
        (1, 1, 0),
        (2, 3, 1),
        (3, 3, 1),
        (4, 5, 2),
        (100000000000000, 100000000000000, 49999999999999),
        (100000000000, 130000000001, 35000000000),
        (100000000000000, 99999999999999, 49999999999999),
        (99999999999999, 100000000000000, 49999999999999),
        (6, 8, 2),
        (8, 14, 1),
        (8, 16, 0),
        (2, 4, 0),
        (41, 66, 8),
        (4827, 5436, 2109),
        (5, 8, 1),
        (38, 74, 2),
        (7, 14, 3),
        (7, 8, 0),
        (7, 10, 1),
        (3294967296, 5, 0),
        (4, 6, 1),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n_val, k_val, expected) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: n={n_val}, k={k_val}")
        
        # Assign inputs
        dut.n.value = n_val
        dut.k.value = k_val
        
        # Wait for combinational logic to settle
        await Timer(10, units='ns')
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"  FAIL: Result is undefined (X/Z)")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f"  FAIL: Expected {expected}, got {result}")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
