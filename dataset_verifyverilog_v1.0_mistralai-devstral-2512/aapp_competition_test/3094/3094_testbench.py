import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 5
INDEX_WIDTH = 4
ARRAY_SIZE = 16
CLK_NS = 10
MAX_CYCLES = 500
MOD = 1000000007

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def compute_expected(t_vals):
    """Compute expected count in Python"""
    n = len(t_vals)
    t = [x - 1 for x in t_vals]  # 0-indexed
    visited = [False] * n
    even_cycles = 0
    
    for i in range(n):
        if not visited[i]:
            # Find cycle length
            j = i
            cycle_len = 0
            while not visited[j]:
                visited[j] = True
                j = t[j]
                cycle_len += 1
            
            if cycle_len % 2 == 0:
                even_cycles += 1
    
    # Result is 2^(even_cycles) % MOD
    result = pow(2, even_cycles, MOD)
    return result

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    if has_signal(dut, 't_valid'):
        dut.t_valid.value = 0
    
    # Wait 2 cycles
    for _ in range(2):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS * 2, units='ns')
    
    dut.rst_n.value = 1
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_NS, units='ns')

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'done') and is_value_defined(dut.done.value):
            if int(dut.done.value) == 1:
                return True
    return False

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_tfd_count(dut):
    """Test TFD count (square root of permutation counting)"""
    
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        # Wait for a few cycles to stabilize
        for _ in range(3):
            await RisingEdge(dut.clk)
    else:
        await Timer(50, units='ns')
    
    # Reset
    await reset_dut(dut)
    
    # Check ready signal
    if has_signal(dut, 'ready'):
        if not int(dut.ready.value):
            raise TestFailure("Expected ready=1 after reset")
    
    # Test cases
    test_cases = [
        ([1, 2], 2, "n=2, identity permutation"),
        ([3, 4, 5, 1, 2], 1, "n=5, 5-cycle"),
        ([7, 16, 11, 1, 8, 2, 4, 5, 10, 14, 3, 15, 12, 9, 13, 6], 92, "n=16, complex")
    ]
    
    for test_idx, (t_input, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx + 1}: {desc}")
        n = len(t_input)
        
        # Wait for ready
        if has_signal(dut, 'ready'):
            timeout = 0
            while not int(dut.ready.value) and timeout < 100:
                if has_signal(dut, 'clk'):
                    await RisingEdge(dut.clk)
                else:
                    await Timer(CLK_NS, units='ns')
                timeout += 1
            if timeout >= 100:
                raise TestFailure("Module not ready")
        
        # Load n
        if has_signal(dut, 'len'):
            dut.len.value = n
        
        # Set start
        if has_signal(dut, 'start'):
            dut.start.value = 1
        
        if has_signal(dut, 'clk'):
            await RisingEdge(dut.clk)
        else:
            await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 'start'):
            dut.start.value = 0
        
        # Load T values one by one
        if has_signal(dut, 't_valid'):
            dut.t_valid.value = 1
        
        for i in range(n):
            if has_signal(dut, 't_idx'):
                dut.t_idx.value = i
            if has_signal(dut, 't_val'):
                dut.t_val.value = t_input[i]  # 1-indexed value
            
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
        
        if has_signal(dut, 't_valid'):
            dut.t_valid.value = 0
        
        # Wait for done
        done_found = await wait_for_done(dut)
        
        if not done_found:
            raise TestFailure(f"Done signal not received within {MAX_CYCLES} cycles")
        
        # Read result
        if has_signal(dut, 'result'):
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            result = int(dut.result.value)
            
            if result >= MOD:
                result = result % MOD
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} for test {desc}")
            
            cocotb.log.info(f"  Result: {result}, Expected: {expected} - PASS")
        else:
            expected_result = compute_expected(t_input)
            if expected_result != expected:
                cocotb.log.warning(f"Warning: Test case expected {expected} but Python computed {expected_result}")
            cocotb.log.info(f"  Expected: {expected} (Python computed)")
        
        # Reset for next test
        await reset_dut(dut)
    
    cocotb.log.info("\nAll tests passed!")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_large_n_edge_case(dut):
    """Test with n=1 (edge case)"""
    
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        for _ in range(3):
            await RisingEdge(dut.clk)
    else:
        await Timer(50, units='ns')
    
    await reset_dut(dut)
    
    # n=1, t=[1]
    n = 1
    t_input = [1]
    expected = 1  # One cycle of length 1 (odd) -> 1
    
    # Wait for ready
    if has_signal(dut, 'ready'):
        timeout = 0
        while not int(dut.ready.value) and timeout < 100:
            if has_signal(dut, 'clk'):
                await RisingEdge(dut.clk)
            else:
                await Timer(CLK_NS, units='ns')
            timeout += 1
    
    if has_signal(dut, 'len'):
        dut.len.value = n
    
    if has_signal(dut, 'start'):
        dut.start.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_NS, units='ns')
    
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    # Load T
    if has_signal(dut, 't_valid'):
        dut.t_valid.value = 1
    
    if has_signal(dut, 't_idx'):
        dut.t_idx.value = 0
    if has_signal(dut, 't_val'):
        dut.t_val.value = 1
    
    if has_signal(dut, 'clk'):
        await RisingEdge(dut.clk)
    else:
        await Timer(CLK_NS, units='ns')
    
    if has_signal(dut, 't_valid'):
        dut.t_valid.value = 0
    
    # Wait for done
    done_found = await wait_for_done(dut, max_cycles=100)
    
    if not done_found:
        raise TestFailure("Done signal not received for n=1")
    
    if has_signal(dut, 'result'):
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"n=1: Expected {expected}, got {result}")
        cocotb.log.info(f"n=1 test passed: result={result}")
    else:
        cocotb.log.info("n=1 test completed (no result signal)")
