import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
MAX_N = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

def is_value_defined(value):
    """Check if a cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    """Safely convert cocotb value to int, returning default if X/Z."""
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def write_array_2d(dut, array_name, values, element_width):
    """Write values to 2D array."""
    arr = getattr(dut, array_name)
    for i, val in enumerate(values):
        arr[i].value = clamp_to_width(val, element_width)

async def read_array_2d(dut, array_name, size):
    """Read values from 2D array."""
    results = []
    arr = getattr(dut, array_name)
    for i in range(size):
        if is_value_defined(arr[i].value):
            results.append(int(arr[i].value))
        else:
            results.append(None)
    return results

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_street_widening(dut):
    """Test street widening module."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases
    test_cases = [
        # (n, [(s1,g1), (s2,g2), ...], expected_total, expected_s_out)
        (3, [(4,5), (4,5), (4,10)], 16, [9, 9, 10]),
        (4, [(1,10), (10,1), (1,10), (10,1)], 22, [11, 11, 11, 11]),
        (3, [(1,1), (100,100), (1,1)], None, None),  # Should error
        (1, [(1,0)], 0, [1]),
        (2, [(2,2), (1,1)], 2, [3, 2]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (n, inputs, expected_total, expected_s) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n}, inputs={inputs}")
        
        try:
            # Write inputs
            s_vals = [s for s, g in inputs]
            g_vals = [g for s, g in inputs]
            
            # Pad to MAX_N with zeros
            s_vals.extend([0] * (MAX_N - n))
            g_vals.extend([0] * (MAX_N - n))
            
            await write_array_2d(dut, 's_in', s_vals, DATA_WIDTH)
            await write_array_2d(dut, 'g_in', g_vals, DATA_WIDTH)
            
            # Set n
            dut.n.value = n
            
            # Start computation
            await start_computation(dut)
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read results
            total_removed = int(dut.total_removed.value)
            error = int(dut.error.value)
            s_out = await read_array_2d(dut, 's_out', n)
            
            if expected_total is None:
                # Should error
                if not error:
                    raise TestFailure(f"Expected error but got error={error}")
                cocotb.log.info(f"  PASS: Correctly detected no solution")
            else:
                # Should succeed
                if error:
                    raise TestFailure(f"Unexpected error={error}")
                if total_removed != expected_total:
                    raise TestFailure(f"Total removed mismatch: expected {expected_total}, got {total_removed}")
                for j in range(n):
                    if s_out[j] != expected_s[j]:
                        raise TestFailure(f"s_out[{j}] mismatch: expected {expected_s[j]}, got {s_out[j]}")
                cocotb.log.info(f"  PASS: total={total_removed}, s_out={s_out[:n]}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")