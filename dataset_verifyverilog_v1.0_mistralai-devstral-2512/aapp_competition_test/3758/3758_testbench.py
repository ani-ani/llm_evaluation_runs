import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

# Test case data (scaled down for fixed size 16 field)
# Encoding: 0='.', 1='*', 2='P'
# We will generate 16x4-bit arrays

def parse_field_to_array(s, max_len=16):
    # s is the input string like '*..P*P*'
    arr = [0] * max_len
    for i, c in enumerate(s[:max_len]):
        if c == '*': arr[i] = 1
        elif c == 'P': arr[i] = 2
        else: arr[i] = 0
    return arr

# Example test cases adapted
TEST_CASES = [
    (*parse_field_to_array('*..P*P*'), 3),
    (*parse_field_to_array('.**PP.*P.*'), 2),
]

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_packmen(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'busy'): dut.busy.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    passed = 0
    failed = 0
    
    for i, case in enumerate(TEST_CASES):
        # Extract field data (first 16 4-bit values) and expected result
        field_data = case[:16]
        expected = case[16]
        
        # Log test
        cocotb.log.info(f"Running Test {i+1}: Expected {expected}")
        
        # Write field array
        for idx, val in enumerate(field_data):
            if has_signal(dut, f'field_{idx}'):
                getattr(dut, f'field_{idx}').value = clamp_to_width(val, 4)
            elif has_signal(dut, f'field'):
                # Assuming a packed array or vector, but spec says 16x4-bit array
                # If it's a vector array, we handle bit slicing
                # For simplicity, assume individual ports or manual unpacking logic
                # If dut.field is a single vector of 64 bits:
                # dut.field.value |= (val << (idx*4))
                # But standard Verilog arrays in Cocotb usually expose individual elements
                # If 'field' is a logic [15:0][3:0], accessing dut.field[idx] should work
                try:
                    dut.field[idx].value = val
                except Exception:
                    # Fallback for packed vector
                    dut.field.value = 0
                    for j, v in enumerate(field_data):
                        dut.field.value |= (v << (j*4))
                    break
        
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        max_cycles = 600  # Allow plenty of time for binary search
        done = False
        for _ in range(max_cycles):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            cocotb.log.error(f"Test {i+1}: Timeout waiting for done")
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f"Test {i+1}: Result is undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f"Test {i+1}: FAIL. Expected {expected}, got {result}")
            failed += 1
        else:
            cocotb.log.info(f"Test {i+1}: PASS")
            passed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
