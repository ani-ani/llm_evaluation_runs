import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# ============================================================================
# CONFIGURATION
# ============================================================================
N_MAX = 8
DATA_WIDTH = 32
FRACT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 256

# ============================================================================
# FIXED-POINT CONVERSION FUNCTIONS
# ============================================================================

def float_to_q16_16(value):
    """Convert float to Q16.16 fixed-point integer."""
    return int(value * (1 << FRACT_WIDTH))

def q16_16_to_float(value):
    """Convert Q16.16 fixed-point integer to float."""
    return value / (1 << FRACT_WIDTH)

def is_value_defined(value):
    """Check if cocotb value is defined (not X or Z)."""
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    """Clamp value to fit within specified bit width."""
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def has_signal(dut, name):
    """Check if DUT has a signal with given name."""
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# ============================================================================
# ARRAY ACCESS HELPERS
# ============================================================================

async def write_array(dut, array_name, values, element_width):
    """Write values to array, handling different interface styles."""
    # Try indexed array first
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
    
    # Try indexed array first
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
# VERIFICATION HELPERS
# ============================================================================

def verify_segment_length(input_len, computed_x, computed_y, prev_x, prev_y):
    """Verify computed segment length matches input within tolerance."""
    dx = computed_x - prev_x
    dy = computed_y - prev_y
    computed_len = ((dx * dx + dy * dy) ** 0.5)
    diff = abs(computed_len - input_len)
    return diff <= 0.01

def verify_tip_position(tip_x, tip_y, target_x, target_y, total_len):
    """Verify tip position is optimal."""
    dist_to_target = ((tip_x - target_x)**2 + (tip_y - target_y)**2)**0.5
    target_dist = (target_x**2 + target_y**2)**0.5
    
    # If within reach, should be able to reach target within 0.01
    if target_dist <= total_len:
        return dist_to_target <= 0.01
    else:
        # If unreachable, tip should be at distance = total_len from origin
        dist_from_origin = (tip_x**2 + tip_y**2)**0.5
        return abs(dist_from_origin - total_len) <= 0.01

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_robotic_arm(dut):
    """Test robotic arm inverse kinematics."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Reachable target (from sample)
    # N=3, lengths=[5,3,4], target=(5,3)
    # Total length = 12, target dist = sqrt(34) ≈ 5.83 (reachable)
    test_cases = [
        {
            'name': 'Sample 1 - Reachable',
            'lengths': [5.0, 3.0, 4.0],
            'target': (5.0, 3.0),
            'expected_tip': (5.0, 3.0),  # Should reach exactly
            'reachable': True
        },
        {
            'name': 'Sample 2 - Unreachable',
            'lengths': [4.0, 2.0],
            'target': (-8.0, -3.0),
            'expected_tip': None,  # Just verify it's stretched
            'reachable': False
        },
        {
            'name': 'Zero target',
            'lengths': [2.0, 2.0],
            'target': (0.0, 0.0),
            'expected_tip': (0.0, 0.0),
            'reachable': True
        }
    ]
    
    total_passed = 0
    total_failed = 0
    
    for test in test_cases:
        cocotb.log.info(f"\n{'='*60}")
        cocotb.log.info(f"Testing: {test['name']}")
        cocotb.log.info(f"Lengths: {test['lengths']}, Target: {test['target']}")
        
        try:
            # Prepare inputs
            N = len(test['lengths'])
            
            # Convert to Q16.16
            target_x = float_to_q16_16(test['target'][0])
            target_y = float_to_q16_16(test['target'][1])
            lengths_q16 = [float_to_q16_16(l) for l in test['lengths']]
            
            # Write inputs to DUT
            dut.target_x.value = target_x
            dut.target_y.value = target_y
            
            # Write segment lengths
            for i in range(N):
                dut.segment_lengths[i].value = lengths_q16[i]
            
            # Start computation
            await start_computation(dut)
            await wait_for_done(dut)
            
            # Read outputs
            x_coords_raw = await read_array(dut, 'x_coords', N)
            y_coords_raw = await read_array(dut, 'y_coords', N)
            
            # Convert back to float
            x_coords = [q16_16_to_float(x) if x is not None else None for x in x_coords_raw]
            y_coords = [q16_16_to_float(y) if y is not None else None for y in y_coords_raw]
            
            cocotb.log.info(f"Computed positions: {list(zip(x_coords, y_coords))}")
            
            # Verify segment lengths
            prev_x, prev_y = 0.0, 0.0
            lengths_ok = True
            for i in range(N):
                if x_coords[i] is None or y_coords[i] is None:
                    raise TestFailure(f"Output coordinate {i} is undefined")
                
                if not verify_segment_length(test['lengths'][i], x_coords[i], y_coords[i], prev_x, prev_y):
                    lengths_ok = False
                    cocotb.log.warning(f"Segment {i} length mismatch")
                prev_x, prev_y = x_coords[i], y_coords[i]
            
            if not lengths_ok:
                raise TestFailure("Segment length verification failed")
            
            # Verify tip position
            total_len = sum(test['lengths'])
            tip_x, tip_y = prev_x, prev_y
            
            if not verify_tip_position(tip_x, tip_y, test['target'][0], test['target'][1], total_len):
                raise TestFailure(f"Tip position {tip_x},{tip_y} not optimal for target {test['target']}")
            
            # Check expected tip if provided
            if test['expected_tip'] is not None:
                exp_x, exp_y = test['expected_tip']
                if abs(tip_x - exp_x) > 0.01 or abs(tip_y - exp_y) > 0.01:
                    cocotb.log.warning(f"Tip {tip_x},{tip_y} differs from expected {exp_x},{exp_y}, but still valid")
            
            cocotb.log.info(f"PASS: {test['name']}")
            total_passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {test['name']} - {e}")
            total_failed += 1
    
    # Summary
    cocotb.log.info(f"\n{'='*60}")
    cocotb.log.info(f"SUMMARY: {total_passed}/{total_passed+total_failed} tests passed")
    
    if total_failed > 0:
        raise TestFailure(f"{total_failed} test(s) failed")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_edge_cases(dut):
    """Test edge cases and robustness."""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test single segment
    dut.target_x.value = float_to_q16_16(10.0)
    dut.target_y.value = float_to_q16_16(0.0)
    dut.segment_lengths[0].value = float_to_q16_16(5.0)
    
    await start_computation(dut)
    await wait_for_done(dut)
    
    x = await read_array(dut, 'x_coords', 1)
    y = await read_array(dut, 'y_coords', 1)
    
    # Should stretch to (5,0) since target is unreachable
    if x[0] is None or y[0] is None:
        raise TestFailure("Single segment test: output undefined")
    
    x_val = q16_16_to_float(x[0])
    y_val = q16_16_to_float(y[0])
    
    if abs(x_val - 5.0) > 0.01 or abs(y_val - 0.0) > 0.01:
        raise TestFailure(f"Single segment: expected (5.0,0.0), got ({x_val},{y_val})")
    
    cocotb.log.info("Edge case tests: PASS")
