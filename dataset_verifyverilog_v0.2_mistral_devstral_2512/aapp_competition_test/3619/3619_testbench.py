import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

# Helper to convert decimal to fixed point Q16.16
def to_q16_16(value):
    return int(value * 65536)

# Helper to convert Q16.16 to decimal
def from_q16_16(value):
    return value / 65536.0

@cocotb.test()
async def test_optimal_team_selector(dut):
    """Test the optimal team selector with scaled down inputs."""
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_valid.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 1: Simple Tree (Example 1 Adapted) ---
    # n=2, k=1. 
    # Node 1: s=1000, p=1, r=0 (root child)
    # Node 2: s=1, p=1000, r=1
    # Optimal: Pick Node 2 (must pick Node 1 to satisfy dependency, but k=1 so only pick 1 total? 
    # Wait, problem says "assign exactly k candidates". If k=1, we can only pick 1 candidate.
    # Dependency: Node 2 needs Node 1. So we must pick Node 1. Value = 1/1000 = 0.001.
    
    dut._log.info("Loading Test Case 1: Chain structure, k=1")
    
    # Load Node 1
    dut.data_valid.value = 1
    dut.node_id.value = 1
    dut.parent_id.value = 0
    dut.salary.value = 1000
    dut.productivity.value = 1
    await RisingEdge(dut.clk)
    
    # Load Node 2
    dut.node_id.value = 2
    dut.parent_id.value = 1
    dut.salary.value = 1
    dut.productivity.value = 1000
    await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done (binary search takes many cycles)
    # With N=2, K=1, we expect result close to 0.001
    # We'll wait a fixed amount of time sufficient for the state machine to finish
    # (e.g., 16 search iterations * DP cycles)
    await Timer(5000, units='ns') 
    
    # Check if done is high
    if not dut.done.value:
        raise TestFailure("Done signal did not go high")
        
    result = int(dut.max_ratio_q16_16.value)
    result_float = from_q16_16(result)
    
    dut._log.info(f"Result for Case 1: {result_float} (Expected ~0.001)")
    
    # Check result (allow small error)
    if abs(result_float - 0.001) > 0.0002:
         raise TestFailure(f"Expected ~0.001, got {result_float}")

    # --- Reset for next test ---
    dut.rst_n.value = 0
    await Timer(10, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # --- Test Case 2: Multiple Root Children (Example 2 Adapted) ---
    # n=3, k=2. 
    # Node 1: s=1, p=100, r=0
    # Node 2: s=1, p=200, r=0
    # Node 3: s=1, p=300, r=0
    # Optimal: Pick 2 largest productivities: 200 + 300 / 1 + 1 = 500 / 2 = 250.
    
    dut._log.info("Loading Test Case 2: Star structure, k=2")
    
    dut.data_valid.value = 1
    # Node 1
    dut.node_id.value = 1
    dut.parent_id.value = 0
    dut.salary.value = 1
    dut.productivity.value = 100
    await RisingEdge(dut.clk)
    
    # Node 2
    dut.node_id.value = 2
    dut.parent_id.value = 0
    dut.salary.value = 1
    dut.productivity.value = 200
    await RisingEdge(dut.clk)
    
    # Node 3
    dut.node_id.value = 3
    dut.parent_id.value = 0
    dut.salary.value = 1
    dut.productivity.value = 300
    await RisingEdge(dut.clk)
    
    dut.data_valid.value = 0
    
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for computation
    await Timer(5000, units='ns')
    
    if not dut.done.value:
        raise TestFailure("Done signal did not go high")
        
    result = int(dut.max_ratio_q16_16.value)
    result_float = from_q16_16(result)
    
    dut._log.info(f"Result for Case 2: {result_float} (Expected ~250.0)")
    
    if abs(result_float - 250.0) > 0.2:
         raise TestFailure(f"Expected ~250.0, got {result_float}")

    dut._log.info("All tests passed!")
