import cocotb
from cocotb.triggers import Timer, RisingEdge
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_airplane_construction(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case 1: Example from problem
    # Map: step1 -> node0 (a_0=15), step2 -> node7 (a_7=20)
    # dep_mask_7 = 1 (node0 is dependency)
    dut.a_0.value = 15
    dut.a_1.value = 0
    dut.a_2.value = 0
    dut.a_3.value = 0
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 20
    
    dut.dep_mask_0.value = 0
    dut.dep_mask_1.value = 0
    dut.dep_mask_2.value = 0
    dut.dep_mask_3.value = 0
    dut.dep_mask_4.value = 0
    dut.dep_mask_5.value = 0
    dut.dep_mask_6.value = 0
    dut.dep_mask_7.value = 1
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    result = int(dut.result.value)
    expected = 15
    if result != expected:
        raise TestFailure(f"Test 1: expected {expected}, got {result}")
    dut._log.info(f"Test 1 PASS: result = {result}")
    
    # Test case 2: Second example
    # Map: step1 -> node0 (10), step2 -> node1 (40), step3 -> node2 (70), step4 -> node3 (10)
    # dep_mask_1 = 1 (node0)
    # dep_mask_2 = 1 (node0)
    # dep_mask_3 = 6 (bits 1 and 2 set for node1 and node2)
    await reset_dut(dut)
    
    dut.a_0.value = 10
    dut.a_1.value = 40
    dut.a_2.value = 70
    dut.a_3.value = 10
    dut.a_4.value = 0
    dut.a_5.value = 0
    dut.a_6.value = 0
    dut.a_7.value = 0
    
    dut.dep_mask_0.value = 0
    dut.dep_mask_1.value = 1
    dut.dep_mask_2.value = 1
    dut.dep_mask_3.value = 6
    dut.dep_mask_4.value = 0
    dut.dep_mask_5.value = 0
    dut.dep_mask_6.value = 0
    dut.dep_mask_7.value = 0
    
    # Start computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Wait for done
    await wait_for_done(dut)
    
    # Check result
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    result = int(dut.result.value)
    expected = 60
    if result != expected:
        raise TestFailure(f"Test 2: expected {expected}, got {result}")
    dut._log.info(f"Test 2 PASS: result = {result}")
    
    dut._log.info("All tests passed!")
