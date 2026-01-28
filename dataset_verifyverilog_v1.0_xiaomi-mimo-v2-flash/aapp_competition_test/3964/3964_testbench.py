import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants based on scaled constraints
MAX_N = 100
MAX_M = 500
MAX_B = 500
DATA_WIDTH = 9  # a_i values (0-500)
RESULT_WIDTH = 30  # mod up to 1e9+7
CLK_NS = 10
MAX_CYCLES = 600000  # n*m*b ~ 25M, but actual cycles less due to optimization

# Helper functions
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

def pack_array_9bit(vals):
    """Pack array of 9-bit values into single signal"""
    result = 0
    for i, v in enumerate(vals):
        result |= (v & 0x1FF) << (i * 9)
    return result

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def wait_for_idle(dut, timeout=100):
    for _ in range(timeout):
        if has_signal(dut, 'state'):
            state = int(dut.state.value)
            if state == 0:  # IDLE
                return True
        await RisingEdge(dut.clk)
    raise TestFailure("Timeout waiting for IDLE state")

@cocotb.test(timeout_time=30000, timeout_unit="ms")
async def test_programming_plans(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
        
        # Wait for IDLE state
        await wait_for_idle(dut)
    
    # Test cases: (n, m, b, mod, a_i list, expected_result, description)
    test_cases = [
        (3, 3, 3, 100, [1, 1, 1], 10, "Example 1: All same bugs"),
        (3, 6, 5, 1000000007, [1, 2, 3], 0, "Example 2: Too many bugs"),
        (3, 5, 6, 11, [1, 2, 1], 0, "Example 3: Mod 11"),
        (2, 3, 3, 1000, [1, 2], 1, "Simple case"),
        (1, 1, 0, 1000, [0], 1, "Single programmer, 0 bugs"),
        (1, 4, 25, 1000, [6], 1, "Single programmer, exact fit"),
        (1, 5, 1, 10, [1], 0, "Single programmer, exceeds bugs"),
        (1, 5, 5, 1000, [1], 1, "Single programmer, exactly m"),
        (1, 5, 5, 1000, [500], 0, "Single programmer, too many bugs"),
        (2, 500, 250, 100, [100, 200], 2, "Large numbers, small mod"),
        (2, 500, 50, 10000, [0, 50], 2, "Zero bugs allowed"),
        (10, 9, 20, 48620, [1,1,1,1,1,1,1,1,2,2], 1002, "Multiple programmers"),
    ]
    
    passed = failed = 0
    
    for i, (n, m, b, mod, a_i, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}/{len(test_cases)}: {desc}")
        cocotb.log.info(f"  Input: n={n}, m={m}, b={b}, mod={mod}")
        cocotb.log.info(f"  a_i: {a_i}")
        
        try:
            # Prepare inputs
            if is_seq:
                # Set parameters
                dut.n.value = n
                dut.m.value = m
                dut.b.value = b
                dut.mod.value = mod
                
                # Pack a_i array
                a_packed = 0
                for idx, val in enumerate(a_i):
                    a_packed |= (val & 0x1FF) << (idx * 9)
                
                # Check if a_i is packed or individual signals
                if has_signal(dut, 'a_i_packed'):
                    dut.a_i_packed.value = a_packed
                elif has_signal(dut, 'a_i'):
                    dut.a_i.value = a_packed
                else:
                    # Individual signals a_i_0, a_i_1...
                    for idx in range(len(a_i)):
                        sig_name = f'a_i_{idx}'
                        if has_signal(dut, sig_name):
                            getattr(dut, sig_name).value = a_i[idx]
                        else:
                            raise TestFailure(f"Cannot set a_i[{idx}]: signal not found")
                
                await RisingEdge(dut.clk)
                
                # Start computation
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result signal undefined")
                
                result = int(dut.result.value)
                
            else:
                # Combinational (shouldn't happen for this problem but handle)
                await Timer(1000, units='ns')
                result = int(dut.result.value) if is_value_defined(dut.result.value) else 0
            
            # Clamp expected to mod
            expected_mod = expected % mod if mod != 0 else expected
            
            cocotb.log.info(f"  Expected: {expected_mod}, Got: {result}")
            
            if result != expected_mod:
                raise TestFailure(f"Mismatch: expected {expected_mod}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
            
        # Reset between tests for sequential design
        if is_seq and i < len(test_cases) - 1:
            await reset_dut(dut)
            await wait_for_idle(dut)
    
    cocotb.log.info(f"\nResults: {passed} passed, {failed} failed")
    
    if failed:
        raise TestFailure(f"{failed} test(s) failed")

@cocotb.test(timeout_time=60000, timeout_unit="ms")
async def test_large_case(dut):
    """Test with larger parameters to verify scaling"""
    is_seq = has_signal(dut, 'clk')
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
        await wait_for_idle(dut)
    
    # Test case: n=100, m=500, b=500, mod=1000000007
    # Using zeros for a_i to get non-zero answer
    n, m, b, mod = 100, 500, 500, 1000000007
    a_i = [0] * 100  # All zeros
    expected = 1  # Only one way when all bugs=0
    
    cocotb.log.info(f"Large test: n={n}, m={m}, b={b}, mod={mod}")
    
    try:
        if is_seq:
            dut.n.value = n
            dut.m.value = m
            dut.b.value = b
            dut.mod.value = mod
            
            # Pack a_i
            a_packed = 0
            for idx, val in enumerate(a_i):
                a_packed |= (val & 0x1FF) << (idx * 9)
            
            if has_signal(dut, 'a_i_packed'):
                dut.a_i_packed.value = a_packed
            elif has_signal(dut, 'a_i'):
                dut.a_i.value = a_packed
            else:
                for idx in range(len(a_i)):
                    if has_signal(dut, f'a_i_{idx}'):
                        getattr(dut, f'a_i_{idx}').value = a_i[idx]
            
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut, max_cycles=MAX_CYCLES)
            
            result = int(dut.result.value)
            expected_mod = expected % mod
            
            if result != expected_mod:
                raise TestFailure(f"Large test failed: expected {expected_mod}, got {result}")
            
            cocotb.log.info(f"Large test PASS: result={result}")
            
    except TestFailure as e:
        cocotb.log.error(f"Large test FAIL: {e}")
        raise