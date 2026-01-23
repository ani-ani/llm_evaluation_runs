import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 8
COUNT_WIDTH = 32
RESULT_WIDTH = 32
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 200

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

def write_detector_data(dut, positions, counts, valid_count):
    for i in range(ARRAY_SIZE):
        port_name = f'pos_{i}'
        if has_signal(dut, port_name):
            val = positions[i] if i < len(positions) else 0
            getattr(dut, port_name).value = clamp_to_width(val, DATA_WIDTH)
    for i in range(ARRAY_SIZE):
        port_name = f'count_{i}'
        if has_signal(dut, port_name):
            val = counts[i] if i < len(counts) else 0
            getattr(dut, port_name).value = clamp_to_width(val, COUNT_WIDTH)
    dut.valid_detectors.value = valid_count

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_phone_network(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([30, 20, 10], [10, 20, 10], 20, "Example 1 scaled"),
        ([10, 20], [23, 17], 23, "Example 2"),
        ([70, 80, 30], [20, 30, 40], 50, "Example 3 scaled"),
        ([50], [100], 100, "Single detector"),
        ([10, 20, 30], [5, 5, 5], 5, "All same counts"),
        ([10, 20, 30], [50, 30, 10], 50, "Decreasing counts"),
        ([10, 20, 30], [10, 20, 30], 30, "Increasing counts"),
        ([5, 50], [100, 50], 100, "Two detectors far apart"),
    ]
    
    passed = 0
    failed = 0
    
    for test_idx, (positions, counts, expected, description) in enumerate(test_cases):
        cocotb.log.info(f"Test {test_idx + 1}: {description}")
        
        try:
            write_detector_data(dut, positions, counts, len(positions))
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result is undefined (X/Z)")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: result = {result}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
        
        await reset_dut(dut)
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
