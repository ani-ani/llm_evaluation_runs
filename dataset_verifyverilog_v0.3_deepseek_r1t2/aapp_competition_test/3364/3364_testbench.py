import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 3
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_operation(dut, op_type, a, b):
    dut.op_type.value = op_type
    dut.a.value = a
    dut.b.value = b
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def read_result(dut):
    await wait_for_done(dut)
    if not is_value_defined(dut.result.value):
        raise TestFailure("Result is undefined (X/Z)")
    return int(dut.result.value)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_dsu(dut):
    """Test the DSU module with scaled-down operations"""
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (op_type, a, b, expected_result, description)
    # op_type: 0=union, 1=query
    test_cases = [
        (1, 1, 3, 0, "Query 1 and 3 before any union"),
        (0, 1, 7, None, "Union 1 and 7"),
        (0, 3, 7, None, "Union 3 and 7"),
        (1, 1, 3, 1, "Query 1 and 3 after unions"),
        (1, 0, 1, 0, "Query 0 and 1 (different sets)"),
        (0, 2, 5, None, "Union 2 and 5"),
        (1, 2, 5, 1, "Query 2 and 5 (same set)"),
        (1, 0, 2, 0, "Query 0 and 2 (different sets)"),
        (0, 0, 1, None, "Union 0 and 1"),
        (1, 0, 2, 1, "Query 0 and 2 (now same set)"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (op_type, a, b, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {description}")
        
        try:
            # Start operation
            await start_operation(dut, op_type, a, b)
            
            # For query operations, verify result
            if op_type == 1:
                result = await read_result(dut)
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
                cocotb.log.info(f"  PASS: Query result = {result}")
            else:
                # For union, just wait for completion
                await wait_for_done(dut)
                cocotb.log.info(f"  PASS: Union completed")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Summary
    cocotb.log.info(f"{'='*50}")
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")