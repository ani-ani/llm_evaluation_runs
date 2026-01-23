import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION - Adjust these to match your HDL design
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

# ============================================================================
# HELPER FUNCTIONS
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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try individual ports first (arr_0, arr_1, ...)
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
    
    # Pad remaining elements if needed
    for i in range(len(values), ARRAY_SIZE):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = 0
        else:
            try:
                arr = getattr(dut, array_name)
                arr[i].value = 0
            except (AttributeError, TypeError):
                pass

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
    
    # Try individual ports first
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            # Try indexed array
            try:
                arr = getattr(dut, array_name)
                if is_value_defined(arr[i].value):
                    results.append(int(arr[i].value))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
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

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    """Wait for done signal with timeout."""
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    """Pulse start signal for one cycle."""
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_module(dut):
    """Main test function."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (inputs, expected_output, description)
    # Expected outputs are sorted for comparison
    test_cases = [
        ([1,2,3,2,3,4,5], [1,4,5], "Test 1: [1,2,3,2,3,4,5] -> [1,4,5]"),
        ([1,2,3,2,4,5], [1,3,4,5], "Test 2: [1,2,3,2,4,5] -> [1,3,4,5]"),
        ([1,2,3,4,5], [1,2,3,4,5], "Test 3: [1,2,3,4,5] -> [1,2,3,4,5]"),
        ([1,1,1,1], [], "Test 4: [1,1,1,1] -> [] (all duplicates)"),
        ([5], [5], "Test 5: [5] -> [5] (single element)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (inputs, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Write inputs using individual port naming
            for idx, val in enumerate(inputs):
                port_name = f"arr_{idx}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
                else:
                    # Fallback to indexed array
                    dut.arr[idx].value = clamp_to_width(val, DATA_WIDTH)
            
            # Pad remaining ports with zeros
            for idx in range(len(inputs), ARRAY_SIZE):
                port_name = f"arr_{idx}"
                if has_signal(dut, port_name):
                    getattr(dut, port_name).value = 0
                else:
                    try:
                        dut.arr[idx].value = 0
                    except:
                        pass
            
            # Set length
            if has_signal(dut, 'len'):
                dut.len.value = len(inputs)
            
            if is_sequential:
                # Start computation and wait for done
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result length
            result_len = 0
            if has_signal(dut, 'result_len'):
                if is_value_defined(dut.result_len.value):
                    result_len = int(dut.result_len.value)
            else:
                # Count non-zero results
                for j in range(ARRAY_SIZE):
                    port_name = f"result_{j}"
                    if has_signal(dut, port_name):
                        val = getattr(dut, port_name).value
                        if is_value_defined(val) and int(val) != 0:
                            result_len += 1
            
            # Read result array
            results = []
            for j in range(result_len):
                port_name = f"result_{j}"
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                    if is_value_defined(val):
                        results.append(int(val))
                    else:
                        results.append(None)
                else:
                    try:
                        val = dut.result[j].value
                        if is_value_defined(val):
                            results.append(int(val))
                        else:
                            results.append(None)
                    except:
                        results.append(None)
            
            # Filter out None values
            results = [r for r in results if r is not None]
            
            # Sort both for comparison (order may vary in hardware)
            results_sorted = sorted(results)
            expected_sorted = sorted(expected)
            
            cocotb.log.info(f"  Input: {inputs}")
            cocotb.log.info(f"  Expected (sorted): {expected_sorted}")
            cocotb.log.info(f"  Got (sorted): {results_sorted}")
            
            if results_sorted != expected_sorted:
                raise TestFailure(f"Expected {expected_sorted}, got {results_sorted}")
            
            cocotb.log.info(f"  PASS")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
