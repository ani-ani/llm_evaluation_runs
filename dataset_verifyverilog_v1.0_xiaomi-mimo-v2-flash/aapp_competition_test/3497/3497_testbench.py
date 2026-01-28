import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
NODE_BITS = 4
MAX_V = 16
CLK_NS = 10

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=500):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def pack_edges(edges_list, v_count):
    # Pack list of (u,v) pairs into a single value or array of values
    # Assuming input is array of 8-bit ports for simplicity in this testbench
    # Structure: edges[i] = (u << 4) | v
    packed = []
    for (u, v) in edges_list:
        val = (u << NODE_BITS) | v
        packed.append(clamp_to_width(val, DATA_WIDTH))
    return packed

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_pig_escape(dut):
    # Clock setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)

    # Test case 1: Sample Input
    # 6 3
    # 0 1, 1 2, 2 3, 2 4, 1 5
    # Pigs at 1, 2, 5
    # Expected output: 0
    v_in = 6
    p_in = 3
    edges_in = [(0,1), (1,2), (2,3), (2,4), (1,5)]
    pigs_in = [1, 2, 5]
    expected_result = 0

    cocotb.log.info(f"Test Case 1: V={v_in}, P={p_in}")
    
    # Set inputs
    dut.V.value = v_in
    dut.P.value = p_in
    
    # Handle edges input (assuming 'edges' is a vector of 8-bit inputs or a single wide port)
    # Check if edges is an array or single port
    try:
        edges_signal = dut.edges
        # If it's an array (list-like)
        if hasattr(edges_signal, '__len__'):
            packed = pack_edges(edges_in, v_in)
            for i, val in enumerate(packed):
                dut.edges[i].value = val
        else:
            # Single packed port (unlikely for 5 edges * 8 bits = 40 bits, but possible)
            packed_val = 0
            for i, (u, v) in enumerate(edges_in):
                packed_val |= ((u << NODE_BITS) | v) << (i * DATA_WIDTH)
            dut.edges.value = packed_val
    except Exception as e:
        cocotb.log.warning(f"Edge assignment issue: {e}. Skipping edge setup if not strictly required by spec structure.")

    # Handle pigs input
    try:
        pigs_signal = dut.pigs
        if hasattr(pigs_signal, '__len__'):
            for i in range(p_in):
                dut.pigs[i].value = pigs_in[i]
        else:
             packed_val = 0
             for i, p in enumerate(pigs_in):
                 packed_val |= p << (i * NODE_BITS)
             dut.pigs.value = packed_val
    except Exception as e:
        cocotb.log.error(f"Pig assignment failed: {e}")

    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    result = int(dut.result.value)
    if result != expected_result:
        raise TestFailure(f"Test 1 Failed: Expected {expected_result}, got {result}")
    
    cocotb.log.info(f"Test 1 Passed: Result {result}")

    # Test case 2
    # 11 3
    # 0 1, 1 2, 0 3, 3 4, 4 5, 5 6, 0 7, 7 8, 8 9, 9 10
    # Pigs at 1, 3, 9
    # Expected output: 3
    v_in = 11
    p_in = 3
    edges_in = [(0,1), (1,2), (0,3), (3,4), (4,5), (5,6), (0,7), (7,8), (8,9), (9,10)]
    pigs_in = [1, 3, 9]
    expected_result = 3

    cocotb.log.info(f"Test Case 2: V={v_in}, P={p_in}")
    await RisingEdge(dut.clk)
    
    # Reset inputs for next test if necessary (usually required by DUT logic to latch new values on start)
    # Here we just update values before start pulse
    dut.V.value = v_in
    dut.P.value = p_in
    
    try:
        edges_signal = dut.edges
        if hasattr(edges_signal, '__len__'):
            packed = pack_edges(edges_in, v_in)
            for i, val in enumerate(packed):
                dut.edges[i].value = val
        else:
            packed_val = 0
            for i, (u, v) in enumerate(edges_in):
                packed_val |= ((u << NODE_BITS) | v) << (i * DATA_WIDTH)
            dut.edges.value = packed_val
    except Exception as e:
        cocotb.log.warning(f"Edge assignment issue: {e}")

    try:
        pigs_signal = dut.pigs
        if hasattr(pigs_signal, '__len__'):
            for i in range(p_in):
                dut.pigs[i].value = pigs_in[i]
        else:
             packed_val = 0
             for i, p in enumerate(pigs_in):
                 packed_val |= p << (i * NODE_BITS)
             dut.pigs.value = packed_val
    except Exception as e:
        cocotb.log.error(f"Pig assignment failed: {e}")

    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    await wait_for_done(dut)
    
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result undefined")
    result = int(dut.result.value)
    if result != expected_result:
        raise TestFailure(f"Test 2 Failed: Expected {expected_result}, got {result}")
    
    cocotb.log.info(f"Test 2 Passed: Result {result}")