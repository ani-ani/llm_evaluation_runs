import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

# Expected results for test cases
# [3,2,1] -> index 0 (even) has 3 (odd) -> fail -> result 0
# [1,2,3] -> index 0 (even) has 1 (odd) -> fail -> result 0  
# [2,1,4] -> index 0 even 2 even, index 1 odd 1 odd, index 2 even 4 even -> pass -> result 1
# Need 16 elements, pad with valid values for completeness

def create_full_array(partial, size=16):
    """Create 16-element array where partial elements must match condition"""
    result = list(partial)
    # Pad with values that satisfy the condition
    for i in range(len(partial), size):
        if i % 2 == 0:  # even index: even value
            result.append(0)  # even
        else:  # odd index: odd value
            result.append(1)  # odd
    return result

# Test cases with full 16-element arrays
test_cases = [
    (create_full_array([3,2,1]), 0, "Case 1: index 0 even has odd"),
    (create_full_array([1,2,3]), 0, "Case 2: index 0 even has odd"),
    (create_full_array([2,1,4]), 1, "Case 3: all indices correct"),
    (create_full_array([]), 1, "Case 4: all zero (even indices have even, odd have odd)"),
    (create_full_array([255]), 0, "Case 5: index 0 has odd (255)"),
]

async def write_array(dut, name, vals, width):
    """Write array values element by element"""
    for i, v in enumerate(vals):
        dut.__getattr__(name)[i].value = clamp_to_width(v, width)

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_even_position(dut):
    # Setup clock
    if not has_signal(dut, 'clk'):
        # Combinational design
        cocotb.log.info("Testing combinational design")
        await Timer(10, units='ns')
        
        passed = 0
        failed = 0
        
        for i, (arr, exp, desc) in enumerate(test_cases):
            cocotb.log.info(f"Test {i+1}: {desc}")
            try:
                # Write array
                for j, v in enumerate(arr):
                    dut.arr[j].value = clamp_to_width(v, 8)
                
                await Timer(10, units='ns')  # Let logic settle
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = int(dut.result.value)
                if result != exp:
                    raise TestFailure(f"Expected {exp}, got {result}")
                
                passed += 1
            except TestFailure as e:
                cocotb.log.error(f"FAIL: {e}")
                failed += 1
        
        if failed:
            raise TestFailure(f"{failed} tests failed")
        
        return
    
    # Sequential design with clock
    cocotb.log.info("Testing sequential design")
    clk = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clk.start())
    
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, (arr, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Write array
            for j, v in enumerate(arr):
                dut.arr[j].value = clamp_to_width(v, 8)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=20)
            
            # Read result
            result = int(dut.result.value)
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            passed += 1
            
            # Brief wait before next test
            await RisingEdge(dut.clk)
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")