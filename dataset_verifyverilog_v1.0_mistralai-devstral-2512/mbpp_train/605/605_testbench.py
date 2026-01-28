import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
CLK_NS = 10
MAX_CYCLES = 200

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=10, timeout_unit="ms")
async def test_prime_checker(dut):
    # Setup
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (num_in, expected_result, description)
    test_cases = [
        (13, 1, "13 is prime"),
        (7, 1, "7 is prime"),
        (101, 1, "101 is prime"),
        (2, 1, "2 is prime"),
        (4, 0, "4 is not prime"),
        (9, 0, "9 is not prime"),
        (1, 0, "1 is not prime"),
        (0, 0, "0 is not prime"),
        (255, 0, "255 is not prime (composite)"),
        (251, 1, "251 is prime"),
        (100, 0, "100 is not prime")
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Apply inputs
            dut.num_in.value = num
            await RisingEdge(dut.clk)
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Check result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
            
            result = int(dut.result.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: Result={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
        
        # Reset for next test
        await RisingEdge(dut.clk)
        
    if failed:
        raise TestFailure(f"{failed} out of {passed+failed} tests failed")
    cocotb.log.info(f"All {passed} tests passed!")