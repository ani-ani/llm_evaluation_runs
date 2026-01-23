import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# MANDATORY HELPER FUNCTIONS
# ============================================================================

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

def to_signed(val, bits):
    """Convert unsigned integer to signed (two's complement)."""
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    """Convert signed integer to unsigned for Verilog assignment."""
    if val < 0:
        return val + (1 << bits)
    return val

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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports (arr_0, arr_1, ...)
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try 2D array first
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    
    # Try individual ports
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    
    return results

# ============================================================================
# SEQUENTIAL MODULE HELPERS
# ============================================================================

async def reset_dut(dut, cycles=2):
    """Reset the DUT (active-low reset)."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid.value) and int(dut.valid.value) == 1:
            return True
        if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
            return True
    raise TestFailure(f"Timeout: no valid or impossible after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_energy_balancer(dut):
    """Main test function for energy balancer."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (num_lamps, lamps, expected_result, description)
    # Lamps are tuples of (x, y, energy)
    test_cases = [
        (
            4,
            [(10,10,5), (10,20,5), (20,10,5), (20,20,5)],
            28.0,
            "Example 1: 4 lamps with equal energy"
        ),
        (
            4,
            [(10,10,5), (10,20,1), (20,10,12), (20,20,8)],
            36.2842712475,
            "Example 2: 4 lamps with varying energy"
        ),
        (
            6,
            [(1,1,15), (5,1,100), (9,1,56), (1,5,1), (5,5,33), (9,5,3)],
            28.970562748,
            "Example 3: 6 lamps in grid"
        ),
        (
            8,
            [(4,4,1), (4,6,1), (4,8,1), (6,6,14), (8,4,1), (8,6,1), (8,8,1), (99,6,-8)],
            32.0,
            "Example 4: 8 lamps with one far away"
        ),
        (
            2,
            [(4,4,2), (8,8,3)],
            None,
            "Example 5: 2 lamps - impossible"
        )
    ]
    
    passed = 0
    failed = 0
    
    for i, (num_lamps, lamps, expected, description) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {description}")
        
        try:
            # Set num_lamps
            dut.num_lamps.value = num_lamps
            
            # Set lamp data (fill all 12 ports)
            for lamp_idx in range(12):
                if lamp_idx < len(lamps):
                    x, y, e = lamps[lamp_idx]
                else:
                    x, y, e = 0, 0, 0
                
                # Set individual signals
                if has_signal(dut, f'x{lamp_idx}'):
                    getattr(dut, f'x{lamp_idx}').value = x
                if has_signal(dut, f'y{lamp_idx}'):
                    getattr(dut, f'y{lamp_idx}').value = y
                if has_signal(dut, f'e{lamp_idx}'):
                    getattr(dut, f'e{lamp_idx}').value = e
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Check result
            if expected is None:
                # Expect impossible
                if not is_value_defined(dut.impossible.value):
                    raise TestFailure("impossible signal not defined")
                if int(dut.impossible.value) != 1:
                    raise TestFailure(f"Expected impossible, but got valid={dut.valid.value}")
                dut._log.info(f"  PASS: Correctly identified as impossible")
            else:
                # Expect valid result
                if not is_value_defined(dut.valid.value):
                    raise TestFailure("valid signal not defined")
                if int(dut.valid.value) != 1:
                    raise TestFailure(f"Expected valid=1, but got {dut.valid.value}")
                
                # Convert expected to Q16.16
                expected_fixed = int(expected * 65536)
                result = int(dut.result.value)
                
                # Allow small rounding error
                if abs(result - expected_fixed) > 100:
                    raise TestFailure(f"Expected {expected} ({expected_fixed}), got {result/65536.0} ({result})")
                
                dut._log.info(f"  PASS: result = {result/65536.0} (expected {expected})")
            
            passed += 1
            
        except TestFailure as e:
            dut._log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")