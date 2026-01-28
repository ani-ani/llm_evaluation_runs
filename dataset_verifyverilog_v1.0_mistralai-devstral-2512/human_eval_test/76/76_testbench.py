import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 16
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_is_simple_power(dut):
    # Start clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')
    
    # Test cases: (x, n, expected_result, description)
    test_cases = [
        (16, 2, True, "16 is power of 2"),
        (143214, 16, False, "143214 not power of 16"),
        (4, 2, True, "4 is power of 2"),
        (9, 3, True, "9 is power of 3"),
        (16, 4, True, "16 is power of 4"),
        (24, 2, False, "24 not power of 2"),
        (128, 4, False, "128 not power of 4 (128 = 4^3.5)"),
        (12, 6, False, "12 not power of 6"),
        (1, 1, True, "1 is power of 1"),
        (1, 12, True, "1 is power of 12"),
        (0, 1, False, "0 is not power of 1"),
        (1, 0, True, "1 is 0^0"),
        (2, 0, False, "2 is not power of 0"),
        (8, 2, True, "8 is power of 2"),
        (3, 2, False, "3 not power of 2"),
        (5, 3, False, "5 not power of 3"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (x, n, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (x={x}, n={n}, expected={expected})")
        
        try:
            # Apply inputs
            dut.x_i.value = clamp_to_width(x, DATA_WIDTH)
            dut.n_i.value = clamp_to_width(n, DATA_WIDTH)
            
            if has_signal(dut, 'clk'):
                # Sequential circuit
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
                
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                
                result = bool(int(dut.result.value))
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            else:
                # Combinational circuit
                await Timer(100, units='ns')
                if not is_value_defined(dut.result.value):
                    raise TestFailure("Result undefined")
                result = bool(int(dut.result.value))
                if result != expected:
                    raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1
        except Exception as e:
            cocotb.log.error(f"ERROR: {desc} - {e}")
            failed += 1
    
    cocotb.log.info(f"Passed: {passed}/{len(test_cases)}")
    if failed:
        raise TestFailure(f"{failed} tests failed out of {len(test_cases)}")
