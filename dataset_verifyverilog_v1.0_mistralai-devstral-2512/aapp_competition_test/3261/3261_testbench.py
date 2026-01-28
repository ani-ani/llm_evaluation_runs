import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Constants for this problem (scaled)
DATA_WIDTH = 16
ROW_COL_WIDTH = 4  # 0-15
CLK_NS = 10
MAX_CYCLES = 1000

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Python reference for the logic
def python_reference(R, C, K):
    # R, C are limits (e.g. 10 means rows 0..9)
    # But the problem inputs R, C are dimensions, so max index is R-1, C-1
    # The prompt says row_limit/col_limit inputs are 0-15. 
    # If R=10, max_idx=9. 
    # Let's map input R (dim) to max_idx (dim-1) in the testbench.
    max_r = R - 1
    max_c = C - 1
    
    r, c = 0, 0
    direction = 0 # 0: Left->Right, 1: Right->Left
    grey_count = 0
    
    for _ in range(K):
        # Check grey condition: (r & c) == 0
        if (r & c) == 0:
            grey_count += 1
        
        # Update position
        if direction == 0: # Moving Right
            if c < max_c:
                c += 1
            else:
                r += 1
                direction = 1
                if r > max_r: break # Should not happen if K <= total cells
        else: # Moving Left
            if c > 0:
                c -= 1
            else:
                r += 1
                direction = 0
                if r > max_r: break
                
    return grey_count

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_hedgehog_grey(dut):
    # Setup clock if seq
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (10, 10, 6, 5),   # Sample 1
        (3, 5, 11, 8),    # Sample 2
        (10, 10, 100, 51),# Sample 3
        (16, 16, 256, 0), # All white check? 0&0=0(Gray), 0&1=0... depends on bits
    ]
    
    passed = 0
    failed = 0
    
    for R, C, K, expected in test_cases:
        # Skip if K > 256 (HW limit)
        if K > 256:
            cocotb.log.info(f"Skipping R={R}, C={C}, K={K} (K > 256)")
            continue
            
        cocotb.log.info(f"Testing R={R}, C={C}, K={K}")
        
        try:
            # Set inputs
            dut.row_limit.value = R - 1  # HW expects max index (0-15)
            dut.col_limit.value = C - 1
            dut.k.value = K
            
            # Start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            # Verify
            ref = python_reference(R, C, K)
            
            if result != ref:
                raise TestFailure(f"Expected {ref}, got {result}")
            
            passed += 1
            cocotb.log.info(f"PASS: Result {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (R={R}, C={C}, K={K}): {e}")
            failed += 1
            
    if failed:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
