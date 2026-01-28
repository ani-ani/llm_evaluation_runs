import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits - 1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

# Testbench Template
class Config:
    MAX_CYCLES = 20000
    CLK_NS = 10
    NODE_WIDTH = 4
    JOKE_WIDTH = 4
    DATA_WIDTH = 32
    NUM_NODES = 16

def pack_load_node(node_id, joke_val):
    """Pack node_id (4b) and joke_val (4b) into load_data."""
    return (joke_val << 4) | node_id

def pack_load_edge(parent, child):
    """Pack parent (4b) and child (4b) into load_data."""
    return (child << 4) | parent

@cocotb.test(timeout_time=Config.MAX_CYCLES, timeout_unit="ps")
async def test_joke_party(dut):
    # --- Setup Clock ---
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, Config.CLK_NS, units='ns').start())
        # Reset
        dut.rst_n.value = 0
        if has_signal(dut, 'start'): dut.start.value = 0
        if has_signal(dut, 'load_valid'): dut.load_valid.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        dut.rst_n.value = 1 # Active high usually for comb

    # --- Test Cases ---
    # Input format: N, V list, Edges list
    # Scaled mapping: V_i -> V_i (assuming 1-16 range for simplicity in this bench)
    
    # Case 1: N=4, V=[2,1,3,4], Edges: 1->2, 1->3, 3->4 (Root 1, Node indices 1-based)
    # In Verilog 0-based: Root 0, Nodes 0-3. V=[2,1,3,4].
    # Edges: 0->1, 0->2, 2->3.
    test_cases = [
        {
            "N": 4,
            "V": [2, 1, 3, 4],  # 1-based values, assumes map to 0-based or keep as is if logic allows
            "edges": [(1, 2), (1, 3), (3, 4)],
            "expected": 6
        },
        {
            "N": 4,
            "V": [3, 4, 5, 6],
            "edges": [(1, 2), (1, 3), (2, 4)],
            "expected": 3
        },
        {
            "N": 6,
            "V": [5, 3, 6, 4, 2, 1],
            "edges": [(1, 2), (1, 3), (1, 4), (2, 5), (5, 6)],
            "expected": 10
        }
    ]

    for case_idx, tc in enumerate(test_cases):
        cocotb.log.info(f"--- Running Test Case {case_idx + 1} ---")
        
        # Reset for new case
        dut.rst_n.value = 0
        if is_seq:
            await RisingEdge(dut.clk)
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        if is_seq: await RisingEdge(dut.clk)

        # --- Load Data ---
        # 1. Load Node Values
        # V_i is 1-100 in problem, scaling to 0-15 for HDL (assuming no clipping needed in spec)
        # Here we just pass the value, assuming HDL internal clamp or specific test case values fit
        for i in range(tc["N"]):
            node_id = i          # 0-based index
            joke_val = tc["V"][i]
            # Clamp joke to 4 bits (0-15) for the testbench safety
            joke_val = clamp_to_width(joke_val, Config.JOKE_WIDTH)
            
            dut.load_data.value = pack_load_node(node_id, joke_val)
            dut.load_addr.value = node_id  # Address < 16
            dut.load_valid.value = 1
            if is_seq: await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.load_valid.value = 0

        # 2. Load Edges
        # Address >= 16. Let's start at 16.
        edge_addr = 16
        for p, c in tc["edges"]:
            # Input is 1-based, convert to 0-based
            parent = p - 1
            child = c - 1
            
            dut.load_data.value = pack_load_edge(parent, child)
            dut.load_addr.value = edge_addr
            dut.load_valid.value = 1
            if is_seq: await RisingEdge(dut.clk)
            else: await Timer(10, units='ns')
            dut.load_valid.value = 0
            edge_addr += 1

        # --- Start Processing ---
        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            timeout = 0
            while not (has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1):
                await RisingEdge(dut.clk)
                timeout += 1
                if timeout > Config.MAX_CYCLES:
                    raise TestFailure(f"Timeout waiting for done in test case {case_idx+1}")
        else:
            # Combinational logic, just wait for propagation
            await Timer(100, units='ns')

        # --- Verify Result ---
        if not has_signal(dut, 'result'):
             raise TestFailure("Result signal missing")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result signal undefined")
            
        result = int(dut.result.value)
        expected = tc["expected"]
        
        if result != expected:
            raise TestFailure(f"Test Case {case_idx+1} Failed: Expected {expected}, Got {result}")
        
        cocotb.log.info(f"Test Case {case_idx+1} Passed: Result {result}")

    cocotb.log.info("All tests passed!")
