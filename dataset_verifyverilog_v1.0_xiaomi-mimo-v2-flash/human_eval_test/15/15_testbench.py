import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(v):
    try:
        int(v)
        return True
    except (ValueError, TypeError):
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, int(v)))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    await RisingEdge(dut.clk)
    for _ in range(cycles - 1):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=256):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

def read_char_array(dut, max_chars=64):
    """Read all character ports and return as string"""
    result = []
    for i in range(max_chars):
        port_name = f'char_{i}'
        if hasattr(dut, port_name):
            val = int(getattr(dut, port_name).value)
            if val == 0:
                break
            result.append(chr(val))
    return ''.join(result)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_string_generator(dut):
    # Setup clock
    clk_period = 10
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    
    await reset_dut(dut)
    
    test_cases = [
        (0, "0"),
        (3, "0 1 2 3"),
        (10, "0 1 2 3 4 5 6 7 8 9 10")
    ]
    
    passed = 0
    failed = 0
    
    for n, expected in test_cases:
        cocotb.log.info(f"Testing n={n}, expecting: '{expected}'")
        
        try:
            # Set input
            dut.n.value = clamp_to_width(n, 4)
            await RisingEdge(dut.clk)
            
            # Start generation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read result
            result = read_char_array(dut)
            
            cocotb.log.info(f"Generated: '{result}'")
            
            if result != expected:
                raise TestFailure(f"Expected '{expected}', got '{result}'")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1
    
    if failed:
        raise TestFailure(f"{failed} of {len(test_cases)} tests failed")
    
    cocotb.log.info(f"All {passed} tests passed!")