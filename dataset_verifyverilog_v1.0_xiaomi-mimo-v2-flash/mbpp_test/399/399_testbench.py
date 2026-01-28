import cocotb
from cocotb.triggers import Timer
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_NS = 10

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def safe_int(v, default=0):
    try: return int(v)
    except: return default

async def write_array(dut, name, vals, width):
    for i in range(ARRAY_SIZE):
        v = vals[i] if i < len(vals) else 0
        getattr(dut, name)[i].value = clamp_to_width(v, width)

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_bitwise_xor(dut):
    # Test cases
    test_cases = [
        ([10, 4, 6, 9], [5, 2, 3, 3], [15, 6, 5, 10]),
        ([11, 5, 7, 10], [6, 3, 4, 4], [13, 6, 3, 14]),
        ([12, 6, 8, 11], [7, 4, 5, 6], [11, 2, 13, 13])
    ]
    
    passed = 0
    failed = 0
    
    for i, (a_vals, b_vals, exp_vals) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: XOR {[a_vals[i] for i in range(len(a_vals))]} with {b_vals}")
        
        try:
            # Write inputs
            for idx in range(ARRAY_SIZE):
                a_val = a_vals[idx] if idx < len(a_vals) else 0
                b_val = b_vals[idx] if idx < len(b_vals) else 0
                dut.a[idx].value = clamp_to_width(a_val, DATA_WIDTH)
                dut.b[idx].value = clamp_to_width(b_val, DATA_WIDTH)
            
            # Wait for propagation
            await Timer(10, units='ns')
            
            # Check results
            for idx in range(ARRAY_SIZE):
                result_val = safe_int(dut.result[idx].value)
                exp_val = exp_vals[idx] if idx < len(exp_vals) else 0
                
                if result_val != exp_val:
                    raise TestFailure(f"Index {idx}: Expected {exp_val}, got {result_val}")
            
            passed += 1
            cocotb.log.info(f"PASS: Test {i+1}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: Test {i+1} - {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")