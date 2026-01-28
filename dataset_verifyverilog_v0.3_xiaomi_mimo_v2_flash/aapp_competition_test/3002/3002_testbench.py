import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
MAX_ENTRIES = 4
CLK_PERIOD_NS = 10

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

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def feed_entries(dut, entries):
    # entries is list of (year, month, odo)
    for i, (y, m, o) in enumerate(entries):
        if i < MAX_ENTRIES:
            dut.year[i].value = y
            dut.month[i].value = m
            dut.odo[i].value = o
    dut.num_entries.value = len(entries)
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_service_checker(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (entries, expected_result, description)
    # result: 00=legit, 01=insufficient, 10=tampered
    test_cases = [
        ([
            (2017, 4, 0),
            (2017, 8, 12000),
            (2018, 8, 42000)
        ], 0, "Sample 1: seems legit"),
        ([
            (2017, 4, 0),
            (2017, 8, 12000),
            (2018, 8, 42001)
        ], 1, "Sample 2: insufficient service"),
        ([
            (2017, 11, 0),
            (2018, 1, 1000)
        ], 2, "Sample 3: tampered odometer"),
        ([
            (2013, 1, 0),
            (2013, 2, 0)
        ], 0, "Sample 4: seems legit"),
        ([
            (1980, 1, 0),
            (1980, 6, 1000)
        ], 1, "Sample 5: insufficient service")
    ]
    
    passed = 0
    failed = 0
    
    for entries, expected, desc in test_cases:
        dut._log.info(f"Test: {desc}")
        
        # Feed entries
        await feed_entries(dut, entries)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 100
        for _ in range(timeout):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout waiting for done")
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result is undefined")
        
        result = int(dut.result.value)
        
        # Decode result
        if result == 0:
            result_str = "seems legit"
        elif result == 1:
            result_str = "insufficient service"
        elif result == 2:
            result_str = "tampered odometer"
        else:
            result_str = f"unknown ({result})"
        
        # Check
        if result == expected:
            dut._log.info(f"  PASS: {result_str}")
            passed += 1
        else:
            expected_str = ["seems legit", "insufficient service", "tampered odometer"][expected]
            dut._log.error(f"  FAIL: Expected {expected_str}, got {result_str}")
            failed += 1
        
        # Wait before next test
        await Timer(100, units='ns')
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    dut._log.info(f"\n{'='*50}")
    dut._log.info(f"Results: {passed}/{passed+failed} tests passed")
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
