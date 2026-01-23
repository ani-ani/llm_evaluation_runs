import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

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
    """Clamp value to fit within specified bit width (unsigned)."""
    max_val = (1 << bits) - 1
    if value < 0:
        # For signed, we assume caller handles conversion
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# ============================================================================
# CONFIGURATION
# ============================================================================

DATA_WIDTH = 32
MAX_N = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 10000

# ============================================================================
# EXPECTED RESULT COMPUTATION (Prim's algorithm in Python)
# ============================================================================

def compute_mst_cost(coords):
    """Compute minimal MST cost for given list of (x,y,z) tuples."""
    n = len(coords)
    if n <= 1:
        return 0
    visited = [False] * n
    dist = [math.inf] * n
    dist[0] = 0
    total_cost = 0
    for _ in range(n):
        # Find min unvisited
        u = -1
        min_val = math.inf
        for i in range(n):
            if not visited[i] and dist[i] < min_val:
                min_val = dist[i]
                u = i
        if u == -1:
            break
        visited[u] = True
        total_cost += min_val
        # Update distances
        for v in range(n):
            if not visited[v]:
                dx = abs(coords[u][0] - coords[v][0])
                dy = abs(coords[u][1] - coords[v][1])
                dz = abs(coords[u][2] - coords[v][2])
                cost = min(dx, dy, dz)
                if cost < dist[v]:
                    dist[v] = cost
    return total_cost

# ============================================================================
# MAIN TEST
# ============================================================================

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_mst_calculator(dut):
    """Test the MST calculator with given examples."""
    
    # Helper to assign coordinates for a planet
    async def assign_planet(idx, x, y, z):
        # Convert to unsigned for Verilog
        x_u = from_signed(x, DATA_WIDTH)
        y_u = from_signed(y, DATA_WIDTH)
        z_u = from_signed(z, DATA_WIDTH)
        # Assign to individual ports
        if idx == 0:
            dut.x0.value = x_u; dut.y0.value = y_u; dut.z0.value = z_u
        elif idx == 1:
            dut.x1.value = x_u; dut.y1.value = y_u; dut.z1.value = z_u
        elif idx == 2:
            dut.x2.value = x_u; dut.y2.value = y_u; dut.z2.value = z_u
        elif idx == 3:
            dut.x3.value = x_u; dut.y3.value = y_u; dut.z3.value = z_u
        elif idx == 4:
            dut.x4.value = x_u; dut.y4.value = y_u; dut.z4.value = z_u
        elif idx == 5:
            dut.x5.value = x_u; dut.y5.value = y_u; dut.z5.value = z_u
        elif idx == 6:
            dut.x6.value = x_u; dut.y6.value = y_u; dut.z6.value = z_u
        elif idx == 7:
            dut.x7.value = x_u; dut.y7.value = y_u; dut.z7.value = z_u
    
    # Reset sequence
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        ([(1,5,10), (7,8,2)], 3),
        ([(-1,-1,-1), (5,5,5), (10,10,10)], 11),
        ([(11,-15,-15), (14,-5,-15), (-1,-1,-5), (10,-4,-1), (19,-4,19)], 4),
        ([(0,0,0)], 0),  # Edge case N=1
    ]
    
    for case_idx, (coords, expected) in enumerate(test_cases):
        dut._log.info(f"Test case {case_idx+1}: N={len(coords)}")
        
        # Assign coordinates for each planet
        for i in range(len(coords)):
            await assign_planet(i, coords[i][0], coords[i][1], coords[i][2])
        # For unused planets, set to zero
        for i in range(len(coords), MAX_N):
            await assign_planet(i, 0, 0, 0)
        
        # Set N
        dut.N.value = len(coords)
        
        # Pulse start
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        cycles = 0
        while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > MAX_CYCLES:
                raise TestFailure(f"Timeout after {MAX_CYCLES} cycles")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined (X/Z)")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Test {case_idx+1}: expected {expected}, got {result}")
        
        dut._log.info(f"  PASS: result = {result}")
        
        # Wait one more cycle before next test
        await RisingEdge(dut.clk)
    
    dut._log.info("All tests passed!")
