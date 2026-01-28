import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_factory(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.config_valid.value = 0
    await Timer(50, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Test Cases: (N, K, edges list, expected_result)
    # Note: edges are (src, dst). Node IDs 1-based in problem, 0-based in HDL logic usually or 1-based. 
    # Assuming HDL uses 1-based node IDs (1 to N) as per problem, 
    # or 0-based. Let's assume 0-based internal (0 to N-1) matching standard Verilog array indexing.
    # Problem: 1..N. We map 1->0, 2->1, ..., N->N-1.
    
    test_cases = [
        # Case 1: 4 nodes (0,1,2,3), K=2. Edges: 0->2, 1->2, 2->3. Dest=3 (index 3). Exp: 2
        {
            "N": 4, "K": 2,
            "edges": [(0, 2), (1, 2), (2, 3)],
            "expected": 2
        },
        # Case 2: 5 nodes, K=2. Edges: 0->2, 2->3, 1->3, 3->4. Dest=4. Exp: 1
        {
            "N": 5, "K": 2,
            "edges": [(0, 2), (2, 3), (1, 3), (3, 4)],
            "expected": 1
        },
        # Case 3: 5 nodes, K=2. Edges: 0->3, 1->2, 2->3, 3->4, 1->3, 2->2. Dest=4. Exp: 2
        {
            "N": 5, "K": 2,
            "edges": [(0, 3), (1, 2), (2, 3), (3, 4), (1, 3), (2, 2)],
            "expected": 2
        }
    ]

    for tc in test_cases:
        N = tc["N"]
        K = tc["K"]
        edges = tc["edges"]
        expected = tc["expected"]
        
        cocotb.log.info(f"Testing Case: N={N}, K={K}, M={len(edges)}, Expected={expected}")

        # Configure Inputs
        # We assume HDL expects packed arrays: edge_src[31:0] where [3:0] is edge 0, [7:4] is edge 1, etc.
        # Similarly for edge_dst.
        
        edge_src_packed = 0
        edge_dst_packed = 0
        for i, (src, dst) in enumerate(edges):
            # Assuming 4-bit width per edge (supports up to 16 nodes)
            # src and dst are 0-based indices (0 to 15)
            edge_src_packed |= (src & 0xF) << (4 * i)
            edge_dst_packed |= (dst & 0xF) << (4 * i)
        
        dut.edge_src.value = edge_src_packed
        dut.edge_dst.value = edge_dst_packed
        dut.num_edges.value = len(edges)
        dut.num_producers.value = K
        dut.config_valid.value = 1
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        dut.config_valid.value = 0

        # Wait for done
        done = False
        for _ in range(500): # Timeout cycles
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"Timeout for case N={N}")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
            
        # Reset for next test
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
