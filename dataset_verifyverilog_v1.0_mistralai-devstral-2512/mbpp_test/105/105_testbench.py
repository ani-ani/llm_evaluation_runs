import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_VAL = (1 << DATA_WIDTH) - 1

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def pack_array(vals, bits=1):
    r = 0
    for i, v in enumerate(vals):
        r |= (int(v) & ((1 << bits) - 1)) << (i * bits)
    return r

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_count(dut):
    # Combinational module, no clock/reset needed
    
    test_cases = [
        (pack_array([True, False, True]), 2, "True,False,True"),
        (pack_array([False, False]), 0, "False,False"),
        (pack_array([True, True, True]), 3, "True,True,True"),
        (pack_array([True, True, True, True, True, True, True, True]), 8, "All True"),
        (pack_array([False, False, False, False, False, False, False, False]), 0, "All False"),
        (pack_array([True, False, True, False, True, False, True, False]), 4, "Alternating"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr_val, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Set array input
            for j in range(DATA_WIDTH):
                bit_val = (arr_val >> j) & 1
                if hasattr(dut, 'arr') and hasattr(dut.arr, '__getitem__'):
                    dut.arr[j].value = bit_val
                elif hasattr(dut, f'arr_{j}'):
                    getattr(dut, f'arr_{j}').value = bit_val
                else:
                    # Try arr as single port
                    dut.arr.value = arr_val
                    break
            
            # Wait for propagation
            await Timer(10, units='ns')
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined")
            
            result = int(dut.result.value)
            result = clamp_to_width(result, DATA_WIDTH)
            
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: got {result}")
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")