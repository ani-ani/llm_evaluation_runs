import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers

def is_value_defined(v):
    try: int(v); return True
    except (ValueError, TypeError): return False

def safe_int(v, default=0):
    try: return int(v)
    except (ValueError, TypeError): return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=5000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Test data scaled to n≤16
TEST_CASES = [
    # (n, c_array, expected_result)
    (4, [1, 1, 1, 4], 1),   # YES
    (5, [1, 1, 5, 2, 1], 0), # NO
    (3, [1, 1, 3], 0),       # NO - root needs 2 children
    (2, [1, 2], 0),          # NO - not enough nodes
    (1, [1], 1),             # YES - single node
    (6, [1, 1, 1, 1, 2, 6], 0), # NO - has 2
    (8, [1, 1, 1, 1, 1, 1, 1, 8], 1), # YES - root with 7 leaves
    (4, [1, 1, 2, 4], 0),    # NO - has 2
    (7, [1, 1, 1, 3, 1, 1, 7], 1), # YES - root, internal node, leaves
]

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_tree_builder(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        # Setup clock
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Verify interface exists
    assert has_signal(dut, 'start'), "Missing start signal"
    assert has_signal(dut, 'done'), "Missing done signal"
    assert has_signal(dut, 'result'), "Missing result signal"
    assert has_signal(dut, 'n_in'), "Missing n_in signal"
    assert has_signal(dut, 'c_in'), "Missing c_in array"
    
    # Set DATA_WIDTH for c_in
    DATA_WIDTH = 5
    ARRAY_SIZE = 16
    
    passed = 0
    failed = 0
    
    for test_idx, (n, c_array, expected) in enumerate(TEST_CASES):
        cocotb.log.info(f"Test {test_idx+1}: n={n}, c={c_array}, expected={'YES' if expected else 'NO'}")
        
        try:
            # Scale n to n_in
            dut.n_in.value = n
            
            # Prepare c_in array (pad to 16 elements, clamp to 5 bits)
            c_padded = c_array + [0] * (ARRAY_SIZE - len(c_array))
            
            # Assign to c_in array - must assign individually
            for i in range(ARRAY_SIZE):
                dut.c_in[i].value = clamp_to_width(c_padded[i], DATA_WIDTH)
            
            if is_seq:
                # Start the computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for completion
                await wait_for_done(dut, max_cycles=5000)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result_val = int(dut.result.value)
            else:
                # Combinational
                await Timer(100, units='ns')
                result_val = int(dut.result.value)
            
            if result_val != expected:
                raise TestFailure(f"Expected {expected}, got {result_val}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Final result
    if failed > 0:
        raise TestFailure(f"{failed} of {passed+failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")
