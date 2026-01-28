import cocotb
from cocotb.triggers import Timer, RisingEdge, ClockCycles
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

async def wait_for_done(dut, max_cycles=300):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_perfect_square(dut):
    """Test perfect square checker with scaled test cases."""
    # Parameters
    DATA_WIDTH = 16
    CLK_NS = 10
    
    # Setup clock and reset
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    
    # Test cases: (input, expected_result, description)
    # Scaled to 16-bit range: max 65535
    test_cases = [
        (0, 1, "0 is perfect square (0*0)"),
        (1, 1, "1 is perfect square (1*1)"),
        (4, 1, "4 is perfect square (2*2)"),
        (9, 1, "9 is perfect square (3*3)"),
        (10, 0, "10 is not perfect square"),
        (16, 1, "16 is perfect square (4*4)"),
        (36, 1, "36 is perfect square (6*6)"),
        (14, 0, "14 is not perfect square"),
        (196, 1, "196 is perfect square (14*14)"),
        (125, 0, "125 is not perfect square"),
        (15625, 1, "15625 is perfect square (125*125)"),
        (255, 0, "255 is not perfect square"),
        (256, 1, "256 is perfect square (16*16)"),
        (65535, 0, "65535 is not perfect square (max 16-bit)"),
        (65025, 1, "65025 is perfect square (255*255)"),
        (65536, 0, "65536 > max 16-bit, clamp to 0"),  # Edge case: overflow
    ]
    
    passed = 0
    failed = 0
    
    for i, (num, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            # Clamp to 16-bit width
            num_clamped = clamp_to_width(num, DATA_WIDTH)
            
            # Drive inputs
            if has_signal(dut, 'num_in'):
                dut.num_in.value = num_clamped
            else:
                # Try alternative names
                if has_signal(dut, 'n'):
                    dut.n.value = num_clamped
                elif has_signal(dut, 'num'):
                    dut.num.value = num_clamped
            
            if has_signal(dut, 'start'):
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                await wait_for_done(dut)
            else:
                # Combinational module - wait for inputs to settle
                await Timer(100, units='ns')
            
            # Read result
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal is undefined")
            
            result = int(dut.result.value) & 1  # Ensure single bit
            
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result} for n={num_clamped}")
            
            passed += 1
            cocotb.log.info(f"  PASS: result={result}")
            
            # Wait before next test
            await Timer(CLK_NS*2, units='ns')
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    # Final results
    cocotb.log.info(f"\nTest Summary: {passed} passed, {failed} failed")
    if failed > 0:
        raise TestFailure(f"{failed} test(s) failed")
