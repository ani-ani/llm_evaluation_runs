import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
DATA_WIDTH = 10          # 10-bit coordinates and length
ARRAY_SIZE = 33          # 4*8 + 1 = 33 elements for max 8 rooms
MAX_ROOMS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

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
        # Handle signed values
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
    
    # Try individual ports
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    """Read array values, handling different interface styles."""
    results = []
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
async def test_phaser_opt(dut):
    """Test the phaser optimizer module."""
    
    # Detect if sequential
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    # Define test cases: (num_rooms, coordinates_flat, ell, expected_max)
    # Coordinates are flattened as [x1,y1,x2,y2, x1,y1,x2,y2, ...]
    test_cases = [
        (
            5,
            [2,1,4,5, 5,1,12,4, 5,5,9,10, 1,6,4,10, 2,11,7,14],
            8,
            4,
            "First example"
        ),
        (
            3,
            [2,2,3,3, 5,3,6,4, 6,6,7,7],
            6,
            3,
            "Second example"
        ),
        (
            1,
            [0,0,10,10],
            20,
            1,
            "Single room"
        ),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (num_rooms, coords_flat, ell, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"\nTest {test_idx+1}: {description}")
        cocotb.log.info(f"  Num rooms: {num_rooms}, ℓ: {ell}")
        
        try:
            # Build full array: coordinates + ℓ
            full_array = coords_flat + [ell]
            
            # Write to DUT array
            for i, val in enumerate(full_array):
                dut.arr[i].value = clamp_to_width(val, DATA_WIDTH)
            
            # Write num_rooms (if signal exists)
            if has_signal(dut, 'num_rooms'):
                dut.num_rooms.value = num_rooms
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")

# ============================================================================
# OPTIONAL: DETECT INTERFACE AND ADAPT
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_interface_detection(dut):
    """Detect interface and adapt test accordingly."""
    
    # Detect signals
    has_clk = has_signal(dut, 'clk')
    has_rst = has_signal(dut, 'rst_n')
    has_start = has_signal(dut, 'start')
    has_arr = has_signal(dut, 'arr')
    has_num_rooms = has_signal(dut, 'num_rooms')
    has_result = has_signal(dut, 'result')
    has_done = has_signal(dut, 'done')
    
    cocotb.log.info(f"Interface detection:")
    cocotb.log.info(f"  clk: {has_clk}, rst_n: {has_rst}, start: {has_start}")
    cocotb.log.info(f"  arr: {has_arr}, num_rooms: {has_num_rooms}")
    cocotb.log.info(f"  result: {has_result}, done: {has_done}")
    
    if not all([has_clk, has_rst, has_start, has_arr, has_num_rooms, has_result, has_done]):
        cocotb.log.warning("Missing required signals. Test may fail.")
    
    # Run basic test if all signals present
    if has_clk and has_rst and has_start and has_arr and has_num_rooms and has_result and has_done:
        cocotb.log.info("Running standard test...")
        # Could call test_phaser_opt(dut) here, but cocotb runs all tests automatically
    else:
        # Skip if missing required signals
        cocotb.log.warning("Skipping due to missing signals.")
        return
