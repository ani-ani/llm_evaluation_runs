import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def safe_int(v, default=0):
    try:
        return int(v)
    except ValueError:
        return default

def to_signed(val, bits):
    return val - (1 << bits) if val >= (1 << (bits-1)) else val

def from_signed(val, bits):
    return val + (1 << bits) if val < 0 else val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

async def wait_for_done(dut, max_cycles=1000):
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

@cocotb.test(timeout_time=100, timeout_unit="ms")
async def test_count_set_bits(dut):
    # Configuration
    DATA_WIDTH = 8
    COUNT_WIDTH = 4
    CLK_NS = 10
    
    # Check required signals
    if not (has_signal(dut, 'clk') and has_signal(dut, 'rst_n') and has_signal(dut, 'start') and has_signal(dut, 'n') and has_signal(dut, 'count') and has_signal(dut, 'done')):
        raise TestFailure("Missing required signals")
    
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    await reset_dut(dut)
    
    # Test cases: (input, expected_count, description)
    test_cases = [
        (0, 0, "Zero input"),
        (1, 1, "Binary 00000001"),
        (2, 1, "Binary 00000010"),
        (3, 2, "Binary 00000011"),
        (4, 1, "Binary 00000100"),
        (6, 2, "Binary 00000110"),
        (255, 8, "All bits set"),
        (170, 4, "Binary 10101010")
    ]
    
    passed = 0
    failed = 0
    
    for i, (inp, exp, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc} (Input={inp}, Expected={exp})")
        try:
            # Set input
            dut.n.value = clamp_to_width(inp, DATA_WIDTH)
            
            # Pulse start
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut, max_cycles=20)  # Should complete in ~9 cycles
            
            # Read result
            if not is_value_defined(dut.count.value):
                raise TestFailure("Count output undefined")
            
            result = int(dut.count.value)
            
            # Check result
            if result != exp:
                raise TestFailure(f"Expected {exp}, got {result}")
            
            # Ensure done is high
            if int(dut.done.value) != 1:
                raise TestFailure("Done signal not asserted")
            
            # Wait one cycle to see done go low
            await RisingEdge(dut.clk)
            if int(dut.done.value) == 1:
                raise TestFailure("Done signal not deasserted after one cycle")
            
            passed += 1
            cocotb.log.info(f"  PASS: count={result}")
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} out of {passed + failed} tests failed")