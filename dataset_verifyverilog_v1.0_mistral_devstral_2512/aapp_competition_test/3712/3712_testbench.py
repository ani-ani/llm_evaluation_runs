import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 4
ARRAY_SIZE = 8
RESULT_WIDTH = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

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
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_student_swap(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (arr0..arr7, expected_result, description)
    test_cases = [
        ([1,2,2,4,3,0,0,0], 2, "Example 1 scaled"),
        ([4,1,1,0,0,0,0,0], 2, "Example 2 scaled"),
        ([0,3,0,4,0,0,0,0], 0, "Example 3 scaled"),
        ([1,1,1,1,1,0,0,0], 0xFFFF, "Impossible case"),
        ([3,3,3,3,3,3,3,3], 0, "All 3's"),
        ([4,4,4,4,0,0,0,0], 0, "All 4's"),
        ([1,2,1,2,1,2,1,2], 4, "Alternating 1-2"),
        ([2,2,2,2,2,2,2,2], 4, "All 2's")
    ]
    
    passed = 0
    failed = 0
    
    for i, (arr, expected, desc) in enumerate(test_cases):
        dut._log.info(f"Test {i+1}: {desc}")
        
        # Assign array elements individually
        for j in range(ARRAY_SIZE):
            if j < len(arr):
                val = arr[j]
            else:
                val = 0
            signal_name = f"arr{j}"
            if has_signal(dut, signal_name):
                getattr(dut, signal_name).value = val
            else:
                raise TestFailure(f"Signal {signal_name} not found")
        
        # Start computation
        await start_computation(dut)
        await wait_for_done(dut)
        
        # Read result
        if not is_value_defined(dut.result.value):
            dut._log.error(f"Test {i+1} FAILED: Result undefined")
            failed += 1
            continue
            
        result = int(dut.result.value)
        
        # Check result
        if result != expected:
            dut._log.error(f"Test {i+1} FAILED: {desc}")
            dut._log.error(f"  Expected: {expected} (0x{expected:X}), Got: {result} (0x{result:X})")
            failed += 1
        else:
            dut._log.info(f"  PASS: result = {result}")
            passed += 1
    
    dut._log.info(f"{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
