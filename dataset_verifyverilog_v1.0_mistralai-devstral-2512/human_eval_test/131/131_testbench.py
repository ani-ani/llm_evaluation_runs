import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value)==1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_digits_module(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    CLK_NS = 10
    
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        cocotb.log.info("Combinational module detected")
    
    # Test cases: (input, expected_product, description)
    test_cases = [
        (5, 5, "single odd digit"),
        (54, 5, "5 is odd, 4 is even"),
        (120, 1, "1 odd, 2/0 even"),
        (5014, 5, "5 is odd, others even"),
        (98765, 315, "9*7*5=315"),
        (5576543, 2625, "5*5*7*5=2625"),
        (2468, 0, "all even digits"),
        (0, 0, "zero"),
        (13579, 945, "1*3*5*7*9=945"),
        (31415, 15, "3*1*1*5=15")
    ]
    
    passed = failed = 0
    
    for i, (n_in, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (n={n_in}, expect={expected})")
        try:
            if is_seq:
                # Sequential: start pulse then wait
                dut.n_in.value = clamp_to_width(n_in, 16)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational: direct assignment
                dut.n_in.value = clamp_to_width(n_in, 16)
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result undefined")
            
            result = int(dut.result.value)
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            passed += 1
            cocotb.log.info(f"  PASS: got {result}")
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")