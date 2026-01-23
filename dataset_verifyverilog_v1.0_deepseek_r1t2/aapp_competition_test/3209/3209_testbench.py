import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

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

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def float_to_q88(f):
    """Convert float to Q8.8 fixed-point integer."""
    return int(f * 256)

def q88_to_float(q):
    """Convert Q8.8 fixed-point integer to float."""
    return q / 256.0

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_edge_array(dut, array_name, values, element_width):
    """Write values to edge array."""
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            # Try indexed array
            try:
                arr = getattr(dut, array_name)
                arr[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_edge_array(dut, array_name, size):
    """Read edge array values."""
    results = []
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            try:
                arr = getattr(dut, array_name)
                val = arr[i].value
                if is_value_defined(val):
                    results.append(int(val))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
                results.append(None)
    return results

async def reset_dut(dut):
    """Reset the DUT."""
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await Timer(100, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_train_planner(dut):
    """Test the TrainPathPlanner module with sample inputs."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Simple path (Hamburg -> Bremen)
    dut._log.info("Test 1: Simple path")
    
    # Set up edges
    edge_from = [0, 0, 1]  # Hamburg=0, Bremen=1, Frankfurt=2
    edge_to = [1, 1, 2]
    edge_dep = [15, 46, 14]
    edge_time = [float_to_q88(68), float_to_q88(55), float_to_q88(226)]  # 68, 55, 226 minutes
    edge_p = [float_to_q88(0.10), float_to_q88(0.50), float_to_q88(0.10)]  # 10%, 50%, 10%
    edge_d = [float_to_q88(5), float_to_q88(60), float_to_q88(120)]  # 5, 60, 120 minutes
    
    # Write to DUT
    dut.origin.value = 0
    dut.destination.value = 1
    dut.num_edges.value = 3
    
    await write_edge_array(dut, 'edge_from', edge_from, 6)
    await write_edge_array(dut, 'edge_to', edge_to, 6)
    await write_edge_array(dut, 'edge_dep', edge_dep, 8)
    await write_edge_array(dut, 'edge_time', edge_time, 16)
    await write_edge_array(dut, 'edge_p', edge_p, 16)
    await write_edge_array(dut, 'edge_d', edge_d, 16)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result = int(dut.result.value)
    result_float = q88_to_float(result)
    
    dut._log.info(f"Result: {result_float} minutes")
    
    # Expected: around 68.3 minutes (simplified calculation)
    if abs(result_float - 68.3) > 5.0:  # Allow some margin
        raise TestFailure(f"Expected ~68.3, got {result_float}")
    
    if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
        raise TestFailure("Should not be impossible")
    
    dut._log.info("Test 1 PASSED")
    
    # Reset for next test
    await reset_dut(dut)
    
    # Test case 2: Impossible path (Amsterdam -> Rotterdam)
    dut._log.info("Test 2: Impossible path")
    
    # Set up edges: Amsterdam=0, Utrecht=1
    edge_from = [0]
    edge_to = [1]
    edge_dep = [10]
    edge_time = [float_to_q88(22)]
    edge_p = [float_to_q88(0.05)]
    edge_d = [float_to_q88(10)]
    
    dut.origin.value = 0  # Amsterdam
    dut.destination.value = 2  # Rotterdam (different from Utrecht)
    dut.num_edges.value = 1
    
    await write_edge_array(dut, 'edge_from', edge_from, 6)
    await write_edge_array(dut, 'edge_to', edge_to, 6)
    await write_edge_array(dut, 'edge_dep', edge_dep, 8)
    await write_edge_array(dut, 'edge_time', edge_time, 16)
    await write_edge_array(dut, 'edge_p', edge_p, 16)
    await write_edge_array(dut, 'edge_d', edge_d, 16)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check impossible flag
    if not is_value_defined(dut.impossible.value):
        raise TestFailure("Impossible flag not defined")
    
    if int(dut.impossible.value) != 1:
        raise TestFailure("Should be impossible but flag not set")
    
    dut._log.info("Test 2 PASSED")
    
    # Summary
    dut._log.info("All tests completed successfully!")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_complex_path(dut):
    """Test with more complex path including multiple connections."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case: BremenVegesack -> Utrecht (scaled down)
    # Nodes: BremenVegesack=0, BremenHbf=1, Leer=2, Osnabruck=3, Amersfoort=4, Utrecht=5, Groningen=6
    # We'll use only 4 nodes to keep it simple
    
    dut._log.info("Test: Complex path with multiple edges")
    
    # Simple path: 0->1->5
    edge_from = [0, 1]
    edge_to = [1, 5]
    edge_dep = [15, 44]
    edge_time = [float_to_q88(10), float_to_q88(51)]
    edge_p = [float_to_q88(0.0), float_to_q88(0.60)]
    edge_d = [float_to_q88(1), float_to_q88(70)]
    
    dut.origin.value = 0
    dut.destination.value = 5
    dut.num_edges.value = 2
    
    await write_edge_array(dut, 'edge_from', edge_from, 6)
    await write_edge_array(dut, 'edge_to', edge_to, 6)
    await write_edge_array(dut, 'edge_dep', edge_dep, 8)
    await write_edge_array(dut, 'edge_time', edge_time, 16)
    await write_edge_array(dut, 'edge_p', edge_p, 16)
    await write_edge_array(dut, 'edge_d', edge_d, 16)
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined")
    
    result = int(dut.result.value)
    result_float = q88_to_float(result)
    
    dut._log.info(f"Complex path result: {result_float} minutes")
    
    # Should be around 10 + 51 + expected_delay = 61 + 0.6*35.5 = 82.3
    if result_float < 60 or result_float > 100:
        raise TestFailure(f"Result {result_float} out of expected range")
    
    if is_value_defined(dut.impossible.value) and int(dut.impossible.value) == 1:
        raise TestFailure("Should not be impossible")
    
    dut._log.info("Complex path test PASSED")
    
    # Summary
    dut._log.info("All complex tests completed successfully!")