import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try:
        int(v); return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name); return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=2000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# Test function for a specific test case
def run_test_case(n, d, parents, expected):
    async def test_tree(dut):
        CLK_NS = 10
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
        
        # Load phase
        dut.load_mode.value = 1
        dut.D_in.value = d
        for i in range(1, n):
            dut.parent_idx.value = i
            dut.parent_val.value = parents[i]
            await RisingEdge(dut.clk)
        
        dut.load_mode.value = 0
        await RisingEdge(dut.clk)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.result.value):
            raise TestFailure("Result undefined")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"Expected {expected}, got {result}")
    
    return test_tree

# Test cases (constrained for Verilog)
TEST_CASES = [
    # Original 4-node case (N=4, D=3, parent[1]=0, parent[2]=0, parent[3]=1)
    (4, 3, [0,0,1], 2),  # Expected: 2
    
    # Small cases
    (3, 100, [0,0], 3),  # Large D, all nodes marked
    (1, 5, [0], 1),      # Single node
    (2, 0, [0], 1),      # D=0, only one node
    (5, 2, [0,0,1,1], 3),  # Star with D=2
]

# Run all tests
@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_all_cases(dut):
    cocotb.log.info("Testing Tree Distance Marking with scaled constraints (N≤16, D≤4)")
    
    passed = 0
    failed = 0
    
    for i, (n, d, parents, expected) in enumerate(TEST_CASES):
        if n > 16 or d > 4:
            cocotb.log.info(f"Test {i+1}: Skipped (N={n}>16 or D={d}>4)")
            continue
        
        cocotb.log.info(f"Test {i+1}: N={n}, D={d}, parents={parents}, expected={expected}")
        
        try:
            test_func = run_test_case(n, d, parents, expected)
            await test_func(dut)
            passed += 1
            cocotb.log.info(f"Test {i+1}: PASSED")
        except TestFailure as e:
            failed += 1
            cocotb.log.error(f"Test {i+1}: FAILED - {e}")
    
    cocotb.log.info(f"\nSummary: {passed} passed, {failed} failed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")