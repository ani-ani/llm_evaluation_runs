import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 8
ARRAY_SIZE = 8
RESULT_WIDTH = 16
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
async def test_barica(dut):
    """Test the Barica module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases: (N, K, plants, expected_energy, expected_path)
    # plants: list of tuples (X, Y, F)
    # expected_path: list of 1-based plant indices
    test_cases = [
        (
            6, 5,
            [(1,1,5), (2,1,5), (1,2,4), (2,3,5), (3,2,30), (3,3,5)],
            5,
            [1, 2, 4, 6]  # plant indices: 1->2->4->6 (correspond to input order)
        ),
        (
            8, 10,
            [(1,1,15), (2,2,30), (1,2,8), (2,1,7), (3,2,8), (2,3,7), (4,2,100), (3,3,15)],
            36,
            [1, 3, 2, 5, 8]  # plant indices: 1->3->2->5->8
        ),
    ]
    
    passed = 0
    failed = 0
    
    for case_idx, (N, K, plants, expected_energy, expected_path) in enumerate(test_cases):
        cocotb.log.info(f"\nTest Case {case_idx+1}: N={N}, K={K}")
        
        try:
            # Write N and K
            if has_signal(dut, 'N'):
                dut.N.value = N
            if has_signal(dut, 'K'):
                dut.K.value = K
            
            # Write plant data
            X_vals = [p[0] for p in plants]
            Y_vals = [p[1] for p in plants]
            F_vals = [p[2] for p in plants]
            
            await write_array(dut, 'X', X_vals, DATA_WIDTH)
            await write_array(dut, 'Y', Y_vals, DATA_WIDTH)
            await write_array(dut, 'F', F_vals, DATA_WIDTH)
            
            # Wait a bit for values to settle
            await Timer(100, units='ns')
            
            # Start computation
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read results
            if not is_value_defined(dut.final_energy.value):
                raise TestFailure("final_energy is undefined (X/Z)")
            
            final_energy = int(dut.final_energy.value)
            
            if not is_value_defined(dut.path_length.value):
                raise TestFailure("path_length is undefined (X/Z)")
            
            path_length = int(dut.path_length.value)
            
            # Read path indices
            path_indices = []
            for i in range(ARRAY_SIZE):
                if i < path_length:
                    val = getattr(dut, f'path_indices[{i}]').value if has_signal(dut, f'path_indices[{i}]') else None
                    if val is None:
                        # Try individual port
                        port_name = f'path_indices_{i}'
                        if has_signal(dut, port_name):
                            val = getattr(dut, port_name).value
                        else:
                            val = dut.path_indices[i].value
                    
                    if is_value_defined(val):
                        path_indices.append(int(val))
                    else:
                        path_indices.append(None)
                else:
                    path_indices.append(None)
            
            # Validate results
            if final_energy != expected_energy:
                raise TestFailure(f"Energy mismatch: expected {expected_energy}, got {final_energy}")
            
            # Validate path length
            if path_length != len(expected_path):
                raise TestFailure(f"Path length mismatch: expected {len(expected_path)}, got {path_length}")
            
            # Validate path indices (first path_length entries)
            for i in range(path_length):
                if path_indices[i] != expected_path[i]:
                    raise TestFailure(f"Path index {i} mismatch: expected {expected_path[i]}, got {path_indices[i]}")
            
            cocotb.log.info(f"  PASS: Energy={final_energy}, Path={path_indices[:path_length]}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")