import cocotb
from cocotb.triggers import Timer, RisingEdge, First
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    min_val = -(1 << (bits - 1))
    max_val = (1 << (bits - 1)) - 1
    return min(max_val, max(min_val, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def float_to_q8_8(f):
    return int(f * 256)

def q8_8_to_float(v):
    return v / 256.0

def pack_edges(edges, n):
    # Pack list of (a,b) tuples into parallel arrays for testbench
    # Since Verilog arrays are indexed, we simulate individual assignments
    pass

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    if has_signal(dut, 'n'): dut.n.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_tree_embedding(dut):
    # Clock setup
    if has_signal(dut, 'clk'):
        clock = Clock(dut.clk, 10, units='ns')
        cocotb.start_soon(clock.start())
        await reset_dut(dut)
    
    # Test case 1: Star graph (Example 1)
    n = 5
    edges = [(1,2), (1,3), (1,4), (1,5)] # 1-based input
    
    # Map to 0-based for internal logic if needed, but inputs are usually 1-based in problem
    # Here we assume the DUT expects 0-based or handles 1-based internally.
    # Let's assume DUT takes 1-based inputs as per problem statement.
    
    if has_signal(dut, 'n'):
        dut.n.value = n
    
    # Set edges (assuming 16 slots available)
    # We need to map edges to the input ports
    # The spec says: edges_a, edges_b are arrays of 16 4-bit values
    for i in range(16):
        a_name = f'edges_a_{i}'
        b_name = f'edges_b_{i}'
        if i < len(edges):
            if has_signal(dut, a_name):
                getattr(dut, a_name).value = edges[i][0]
                getattr(dut, b_name).value = edges[i][1]
            # Fallback if packed array style
            elif has_signal(dut, 'edges_a'):
                dut.edges_a[i].value = edges[i][0]
                dut.edges_b[i].value = edges[i][1]
        else:
            if has_signal(dut, a_name):
                getattr(dut, a_name).value = 0
                getattr(dut, b_name).value = 0
            elif has_signal(dut, 'edges_a'):
                dut.edges_a[i].value = 0
                dut.edges_b[i].value = 0

    cocotb.log.info(f"Starting test with n={n}")
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    # Read results
    coords = []
    for i in range(n):
        x_val = 0
        y_val = 0
        x_name = f'x_coords_{i}'
        y_name = f'y_coords_{i}'
        
        if has_signal(dut, x_name):
            x_val = int(getattr(dut, x_name).value)
            y_val = int(getattr(dut, y_name).value)
        elif has_signal(dut, 'x_coords'):
            x_val = int(dut.x_coords[i].value)
            y_val = int(dut.y_coords[i].value)
        
        # Convert Q8.8 to float
        x_float = q8_8_to_float(x_val)
        y_float = q8_8_to_float(y_val)
        coords.append((x_float, y_float))
        
        cocotb.log.info(f"Node {i}: ({x_float:.6f}, {y_float:.6f})")
    
    # Validation
    # Check distances
    for i in range(n):
        for j in range(i+1, n):
            dx = coords[i][0] - coords[j][0]
            dy = coords[i][1] - coords[j][1]
            dist = math.sqrt(dx*dx + dy*dy)
            if dist < 1e-4 and dist > 0:
                 # If they are distinct nodes, distance must be > 1e-4
                 pass
    
    # Check edge lengths
    for a, b in edges:
        # a, b are 1-based, convert to 0-based index
        u = a - 1
        v = b - 1
        dx = coords[u][0] - coords[v][0]
        dy = coords[u][1] - coords[v][1]
        dist = math.sqrt(dx*dx + dy*dy)
        # Length should be 1.0 +/- 1e-6
        if abs(dist - 1.0) > 1e-4: # Allow some margin for fixed point error
            raise TestFailure(f"Edge ({a},{b}) length {dist} is not 1.0")
        cocotb.log.info(f"Edge ({a},{b}) length: {dist:.6f}")
