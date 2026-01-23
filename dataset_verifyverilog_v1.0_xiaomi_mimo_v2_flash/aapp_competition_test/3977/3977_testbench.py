import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

# Main test
@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_government_graph(dut):
    # Start clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        # (n, k, gov_nodes, m, edges, expected)
        (4, 2, [0, 2], 1, [(0, 1)], 2),
        (3, 1, [2], 3, [(0, 1), (0, 2), (1, 2)], 0),
        (5, 2, [0, 4], 2, [(0, 1), (2, 3)], 5),
        (2, 1, [0], 0, [], 0),
        (6, 2, [0, 3], 4, [(0, 1), (1, 2), (3, 4), (4, 5)], 5),
    ]
    
    for n, k, gov_nodes, m, edges, expected in test_cases:
        # Prepare inputs
        dut.n.value = n
        dut.k.value = k
        dut.gov0.value = gov_nodes[0]
        dut.gov1.value = gov_nodes[1] if k > 1 else 0
        dut.gov2.value = gov_nodes[2] if k > 2 else 0
        dut.m.value = m
        
        # Pack edges into 96-bit vector (16 edges * 6 bits)
        packed_edges = 0
        for i, (u, v) in enumerate(edges):
            packed_edges |= (u << (6*i)) | (v << (6*i + 3))
        dut.edges.value = packed_edges
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (with timeout)
        cycles = 0
        while not (is_value_defined(dut.done.value) and int(dut.done.value) == 1):
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 1000:
                raise TestFailure("Timeout waiting for done")
        
        # Check result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for case: n={n}, k={k}")
        
        actual = int(dut.result.value)
        if actual != expected:
            raise TestFailure(f"Case: n={n}, k={k}, gov={gov_nodes}, edges={edges} -> Expected {expected}, got {actual}")
        
        dut._log.info(f"Test passed for n={n}, k={k}: result={actual}")
        await RisingEdge(dut.clk)  # Buffer between tests