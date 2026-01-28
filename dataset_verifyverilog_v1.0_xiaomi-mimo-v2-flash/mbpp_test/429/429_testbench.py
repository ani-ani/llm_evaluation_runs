import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH, ARRAY_SIZE, CLK_NS, MAX_CYCLES = 8, 8, 10, 1000

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# ARRAY WRITING (CRITICAL)
async def write_array(dut, name, vals, width):
    for i, v in enumerate(vals):
        if i >= ARRAY_SIZE: break
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

# RESET & DONE
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_and_tuples(dut):
    if not has_signal(dut, 'clk'):
        await Timer(100, units='ns')
        return
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (arr1, arr2, len, expected_result, description)
    test_cases = [
        ([10, 4, 6, 9, 0, 0, 0, 0], [5, 2, 3, 3, 0, 0, 0, 0], 4, [0, 0, 2, 1, 0, 0, 0, 0], "Test 1: (10,4,6,9) & (5,2,3,3) = (0,0,2,1)"),
        ([1, 2, 3, 4, 0, 0, 0, 0], [5, 6, 7, 8, 0, 0, 0, 0], 4, [1, 2, 3, 0, 0, 0, 0, 0], "Test 2: (1,2,3,4) & (5,6,7,8) = (1,2,3,0)"),
        ([8, 9, 11, 12, 0, 0, 0, 0], [7, 13, 14, 17, 0, 0, 0, 0], 4, [0, 9, 10, 0, 0, 0, 0, 0], "Test 3: (8,9,11,12) & (7,13,14,17) = (0,9,10,0)")
    ]
    
    passed = 0
    failed = 0
    
    for idx, (arr1_vals, arr2_vals, length, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {idx+1}: {desc}")
        
        try:
            # Write inputs
            await write_array(dut, 'arr1', arr1_vals, DATA_WIDTH)
            await write_array(dut, 'arr2', arr2_vals, DATA_WIDTH)
            dut.len.value = length
            
            # Trigger operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for completion
            await wait_for_done(dut, max_cycles=20)
            
            # Read and verify results
            if not has_signal(dut, 'result'):
                raise TestFailure("Result signal not found")
            
            actual_results = []
            for i in range(ARRAY_SIZE):
                try:
                    result_val = int(dut.__getattr__('result')[i].value)
                    actual_results.append(result_val)
                except:
                    raise TestFailure(f"Cannot read result[{i}]")
            
            # Compare
            for i in range(ARRAY_SIZE):
                if i >= length:
                    expected_val = 0
                else:
                    expected_val = expected[i]
                
                actual_val = actual_results[i]
                if actual_val != expected_val:
                    raise TestFailure(f"Position {i}: expected {expected_val}, got {actual_val}")
            
            cocotb.log.info(f"  PASS: Result = {actual_results[:length]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        # Small delay between tests
        await Timer(50, units='ns')
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed, {passed} passed")
    
    cocotb.log.info(f"\nAll {passed} tests passed successfully!")