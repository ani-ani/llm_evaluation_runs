import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# ============================================================================
# CONFIGURATION
# ============================================================================
FIXED_WIDTH = 32
INT_BITS = 12
FRAC_BITS = 20
SCALE = 1 << FRAC_BITS  # 1048576
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000
MAX_N = 8

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

def float_to_fixed(f, frac_bits=FRAC_BITS):
    """Convert float to fixed-point integer."""
    return int(f * (1 << frac_bits))

def fixed_to_float(fixed, frac_bits=FRAC_BITS):
    """Convert fixed-point integer to float."""
    return fixed / (1 << frac_bits)

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
# COMPUTE EXPECTED RESULT (Python ground truth)
# ============================================================================

def compute_expected(roost, spots):
    """Compute minimum distance using Python (brute-force DP)."""
    N = len(spots)
    if N == 0:
        return 0.0
    
    # Precompute distances
    dist_roost = [math.hypot(roost[0]-s[0], roost[1]-s[1]) for s in spots]
    dist_spot = [[0.0]*N for _ in range(N)]
    for i in range(N):
        for j in range(N):
            if i != j:
                dist_spot[i][j] = math.hypot(spots[i][0]-spots[j][0], spots[i][1]-spots[j][1])
    
    # DP over subsets
    dp = [1e18] * (1 << N)
    dp[0] = 0.0
    
    for mask in range(1, 1 << N):
        # Single spot trip
        for i in range(N):
            if mask & (1 << i):
                prev = mask ^ (1 << i)
                cost = dp[prev] + 2 * dist_roost[i]
                if cost < dp[mask]:
                    dp[mask] = cost
        # Two-spot trips
        for i in range(N):
            if mask & (1 << i):
                for j in range(i+1, N):
                    if mask & (1 << j):
                        prev = mask ^ (1 << i) ^ (1 << j)
                        cost = dp[prev] + dist_roost[i] + dist_spot[i][j] + dist_roost[j]
                        if cost < dp[mask]:
                            dp[mask] = cost
    
    return dp[(1 << N) - 1]

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_fox_hiding_distance(dut):
    """Main test function for fox hiding distance module."""
    
    # Detect module type
    is_sequential = has_signal(dut, 'clk')
    
    if is_sequential:
        # Start clock
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        
        # Reset
        await reset_dut(dut)
    
    # Define test cases
    # Format: (roost_x, roost_y, N, list of (x,y) spots, expected_result)
    test_cases = [
        # Test case 1 from example
        (
            10.000000, 20.123456, 1,
            [(13.141593, 20.123456)],
            3.141593
        ),
        # Test case 2 from example (adjusted for N=4)
        (
            5.000000, 5.000000, 4,
            [
                (2.000000, 9.000000),
                (14.000000, 17.000000),
                (6.500000, 3.000000),
                (14.000000, 18.500000)
            ],
            31.500000
        ),
    ]
    
    passed = 0
    failed = 0
    
    for tc_idx, (roost_x, roost_y, N, spots, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {tc_idx+1}: roost=({roost_x},{roost_y}), N={N}")
        
        try:
            # Convert to fixed-point
            roost_x_fp = float_to_fixed(roost_x)
            roost_y_fp = float_to_fixed(roost_y)
            spots_x_fp = [float_to_fixed(s[0]) for s in spots]
            spots_y_fp = [float_to_fixed(s[1]) for s in spots]
            
            # Write inputs
            dut.roost_x.value = roost_x_fp
            dut.roost_y.value = roost_y_fp
            dut.N.value = N
            
            # Write spot coordinates (must assign individually)
            for i in range(N):
                dut.spot_x[i].value = spots_x_fp[i]
                dut.spot_y[i].value = spots_y_fp[i]
            
            # For unused spots, set to 0
            for i in range(N, MAX_N):
                dut.spot_x[i].value = 0
                dut.spot_y[i].value = 0
            
            if is_sequential:
                # Start computation
                await start_computation(dut)
                await wait_for_done(dut)
            else:
                # Combinational - wait for propagation
                await Timer(1000, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result_fp = int(dut.result.value)
            result_float = fixed_to_float(result_fp)
            
            # Compare with expected
            tolerance = 1e-6
            if abs(result_float - expected) > tolerance:
                raise TestFailure(f"Expected {expected:.6f}, got {result_float:.6f} (diff={abs(result_float-expected):.6e})")
            
            cocotb.log.info(f"  PASS: result = {result_float:.6f}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
