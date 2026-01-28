import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_berry_birds(dut):
    # Setup Clock and Reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        await Timer(20, units='ns')
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    else:
        await Timer(100, units='ns') # Combinational delay

    # Test Case 1: Sample Input 1 adapted for small scale
    # We map the 13-node example to a smaller set if needed, or just test logic.
    # For this benchmark, we will simulate a simplified conflict scenario.
    # Scenario: 2 Tiny birds (label 'a') with parent 2. Parent 2 is Small branch. 
    # Parent of 2 is 1 (Big). 
    # If both become Giant, they both map to Area of 1. Conflict!
    # So we expect 1 change.

    dut._log.info("Configuring tree...")
    
    # Node 1: Root (Big Branch)
    dut.node_idx.value = 1
    dut.parent.value = 0
    dut.is_branch.value = 1
    dut.is_big_branch.value = 1
    dut.type.value = 3 # Branch code
    dut.label.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
    else:
        await Timer(10, units='ns')

    # Node 2: Small Branch
    dut.node_idx.value = 2
    dut.parent.value = 1
    dut.is_branch.value = 1
    dut.is_big_branch.value = 0
    dut.type.value = 3
    dut.label.value = 0
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Node 3: Tiny Bird 'a', Parent 2
    dut.node_idx.value = 3
    dut.parent.value = 2
    dut.is_branch.value = 0
    dut.is_big_branch.value = 0
    dut.type.value = 1 # Tiny
    dut.label.value = 0 # 'a'
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Node 4: Tiny Bird 'a', Parent 2
    dut.node_idx.value = 4
    dut.parent.value = 2
    dut.is_branch.value = 0
    dut.is_big_branch.value = 0
    dut.type.value = 1 # Tiny
    dut.label.value = 0 # 'a'
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Node 5: Berry 'a', Parent 2
    dut.node_idx.value = 5
    dut.parent.value = 2
    dut.is_branch.value = 0
    dut.is_big_branch.value = 0
    dut.type.value = 2 # Berry
    dut.label.value = 0 # 'a'
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')

    # Finish Config
    dut.config_done.value = 1
    await RisingEdge(dut.clk) if has_signal(dut, 'clk') else Timer(10, units='ns')
    dut.config_done.value = 0

    # Wait for result
    if has_signal(dut, 'result_valid'):
        timeout = 0
        while not int(dut.result_valid.value) and timeout < 100:
            await RisingEdge(dut.clk)
            timeout += 1
        if timeout >= 100:
            raise TestFailure("Timeout waiting for result")
    else:
        # Combinational or implicit
        await Timer(100, units='ns')

    # Check Result
    # We expect at least 1 change because the two Tiny birds collide after becoming Giant.
    min_changes = int(dut.min_changes.value)
    dut._log.info(f"Result: min_changes={min_changes}")
    
    if min_changes < 1:
        raise TestFailure(f"Expected at least 1 change, got {min_changes}")

    # Check if specific nodes are marked for change (optional, depends on heuristic)
    # For this simple case, we just verify a change is needed.
    
    dut._log.info("Test passed!")