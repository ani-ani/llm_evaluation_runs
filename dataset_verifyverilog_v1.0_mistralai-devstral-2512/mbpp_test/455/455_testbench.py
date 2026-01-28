import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

DATA_WIDTH = 4
CLK_NS = 10
MAX_CYCLES = 1000

# Helper functions from template
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_month_has_31_days(dut):
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic only
        await Timer(100, units='ns')
    
    # Test cases: (month, expected_result, description)
    test_cases = [
        (1, True, "January (31 days)"),
        (2, False, "February (28/29 days)"),
        (3, True, "March (31 days)"),
        (4, False, "April (30 days)"),
        (5, True, "May (31 days)"),
        (6, False, "June (30 days)"),
        (7, True, "July (31 days)"),
        (8, True, "August (31 days)"),
        (9, False, "September (30 days)"),
        (10, True, "October (31 days)"),
        (11, False, "November (30 days)"),
        (12, True, "December (31 days)"),
        (0, False, "Invalid month 0"),
        (13, False, "Invalid month 13"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (month, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (month={month})")
        try:
            # Set inputs
            dut.month.value = month & 0xF
            
            if has_signal(dut, 'start'):
                # Sequential logic - trigger start
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut, max_cycles=50)
                
                # Check done signal
                if not is_value_defined(dut.done.value) or int(dut.done.value) != 1:
                    raise TestFailure("done signal did not pulse")
            else:
                # Combinational logic
                await Timer(10, units='ns')
            
            # Read result
            if not is_value_defined(dut.has_31_days.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.has_31_days.value) == 1
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Additional random test cases
    cocotb.log.info("Running random tests...")
    for _ in range(20):
        month = random.randint(0, 15)
        expected = month in [1, 3, 5, 7, 8, 10, 12]
        
        dut.month.value = month & 0xF
        
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut, max_cycles=50)
        else:
            await Timer(10, units='ns')
        
        if not is_value_defined(dut.has_31_days.value):
            raise TestFailure("Result undefined in random test")
        
        result = int(dut.has_31_days.value) == 1
        
        if result != expected:
            raise TestFailure(f"Random test failed: month={month}, expected={expected}, got={result}")
        
        passed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
    
    cocotb.log.info(f"All {passed} tests passed!")