import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# Fixed-point conversion functions
FRAC_BITS = 16
INT_BITS = 16

float_to_fixed = lambda f: int(f * (1 << FRAC_BITS))
fixed_to_float = lambda f: f / (1 << FRAC_BITS)

# Helper to write arrays
def write_array(dut, array_name, values, width=32):
    """Write values to array, handling different interface styles."""
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, width)
        else:
            # Try indexed access
            try:
                getattr(dut, f"{array_name}__{i}").value = clamp_to_width(val, width)
            except AttributeError:
                raise TestFailure(f"Cannot find array port: {array_name}[{i}]")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_key_assignment(dut):
    """Test key-person assignment module"""
    
    # Configuration
    CLK_PERIOD_NS = 10
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (people, keys, office, expected_time, description)
    test_cases = [
        # Example 1
        ([20.0, 100.0], [60.0, 10.0, 40.0, 80.0], 50.0, 50.0, "Example 1: people=2, keys=4, office=50"),
        # Example 2
        ([11.0], [15.0, 7.0], 10.0, 7.0, "Example 2: people=1, keys=2, office=10"),
        # Additional test case
        ([10.0, 4.0], [29.0, 23.0, 21.0, 22.0, 26.0], 15.0, 23.0, "Additional: people=2, keys=5, office=15"),
        # Edge case: same positions
        ([10.0], [10.0], 10.0, 0.0, "Edge: person and key at same position"),
        # Edge case: keys before people
        ([50.0], [10.0, 20.0], 5.0, 45.0, "Edge: keys before office"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (people, keys, office, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Convert to fixed-point
            people_fixed = [float_to_fixed(p) for p in people]
            keys_fixed = [float_to_fixed(k) for k in keys]
            office_fixed = float_to_fixed(office)
            expected_fixed = float_to_fixed(expected)
            
            # Write inputs
            write_array(dut, 'people_pos', people_fixed, 32)
            write_array(dut, 'key_pos', keys_fixed, 32)
            dut.office_pos.value = office_fixed
            dut.valid_people.value = len(people)
            dut.valid_keys.value = len(keys)
            
            # Start computation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            if not is_value_defined(dut.min_max_time.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fixed = int(dut.min_max_time.value)
            result_float = fixed_to_float(result_fixed)
            
            # Allow small rounding error (1 unit in fixed-point)
            error = abs(result_float - expected)
            if error > 1.0 / (1 << FRAC_BITS):
                raise TestFailure(f"Expected {expected:.4f}, got {result_float:.4f} (error={error:.4f})")
            
            cocotb.log.info(f"  PASS: result = {result_float:.4f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
