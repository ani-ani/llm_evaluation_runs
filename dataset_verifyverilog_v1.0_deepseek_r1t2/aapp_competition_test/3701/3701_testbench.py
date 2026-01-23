import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

@cocotb.test(timeout_time=1000, timeout_unit='ms')
async def test_min_cost(dut):
    """Test min_cost module with various cases"""
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        # (string, x, y, expected)
        ("01000", 1, 10, 11),
        ("01000", 10, 1, 2),
        ("1111111", 2, 3, 0),
        ("0", 60754033, 959739508, 959739508),
        ("1", 431963980, 493041212, 0),
        ("00", 163093925, 214567542, 214567542),
        ("10", 340351106, 646854722, 646854722),
        ("010", 505700940, 617334451, 1142645167),
        ("110", 75308005, 971848814, 971848814),
        ("001", 212627893, 854138703, 854138703),
        ("101", 31395883, 981351561, 981351561),
        ("011", 118671447, 913685773, 913685773),
        ("10110100011001", 3, 11, 20),
        ("1010101010101010101", 1, 1, 9),
        ("0000", 522194562, 717060616, 717060616),
        ("1000", 659514449, 894317797, 894317797),
        ("0100", 71574977, 796834337, 868409314),
        ("1100", 248832158, 934154224, 934154224),
        ("0010", 71474110, 131122047, 202596157),
        ("1010", 308379228, 503761290, 812140518),
        ("0110", 272484957, 485636409, 758121366),
        ("1110", 662893590, 704772137, 704772137),
        ("0001", 545183479, 547124732, 547124732),
        ("1001", 684444619, 722440661, 722440661),
        ("0101", 477963686, 636258459, 1114222145),
        ("1101", 360253575, 773578347, 773578347),
        ("0011", 832478048, 910898234, 910898234),
        ("1011", 343185412, 714767937, 714767937),
        ("0111", 480505300, 892025118, 892025118),
        ("1111", 322857895, 774315007, 0),
    ]
    
    for s, x, y, expected in test_cases:
        # Pad string with ones to 16 bits
        padded = s + '1' * (16 - len(s))
        # Convert to 16-bit value: first char at bit0, last char at bit15
        a_val = 0
        for i, char in enumerate(padded):
            if char == '1':
                a_val |= (1 << i)
        
        # Drive inputs
        dut.a.value = a_val
        dut.x.value = clamp_to_width(x, 32)
        dut.y.value = clamp_to_width(y, 32)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done with timeout
        cycles = 0
        while True:
            await RisingEdge(dut.clk)
            cycles += 1
            if cycles > 50:  # Max expected: 16 (traverse) + 15 (compute) + states
                raise TestFailure(f"Timeout for string {s}")
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        
        # Read result
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for {s}")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"String {s}: expected {expected}, got {result}")
        
        dut._log.info(f"Test passed for '{s}': {result}")
        await RisingEdge(dut.clk)  # Buffer between tests
