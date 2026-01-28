import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_total_match(dut):
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: [] vs []
    await run_test(dut, [], [], 0, 0)
    
    # Test case 2: ['hi', 'admin'] vs ['hI', 'Hi'] (2+5=7 vs 2+2=4) -> second
    await run_test(dut, ['hi', 'admin'], ['hI', 'Hi'], 1, 2)
    
    # Test case 3: ['hi', 'admin'] vs ['hi', 'hi', 'admin', 'project'] (7 vs 2+2+5+7=16) -> first
    await run_test(dut, ['hi', 'admin'], ['hi', 'hi', 'admin', 'project'], 0, 2)
    
    # Test case 4: ['4'] vs ['1', '2', '3', '4', '5'] (1 vs 1+1+1+1+1=5) -> first
    await run_test(dut, ['4'], ['1', '2', '3', '4', '5'], 0, 1)
    
    # Test case 5: equal counts -> return first
    await run_test(dut, ['ab', 'cd'], ['a', 'b', 'c', 'd'], 0, 2)
    
async def run_test(dut, list1, list2, expected_select, expected_len):
    cocotb.log.info(f"Testing: {list1} vs {list2}")
    
    # Calculate expected totals
    total1 = sum(len(s) for s in list1)
    total2 = sum(len(s) for s in list2)
    
    # Wait for idle
    await RisingEdge(dut.clk)
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    
    # Send first list
    dut.str1_valid.value = 1
    dut.str2_valid.value = 0
    for string in list1:
        for i, char in enumerate(string.encode()):
            dut.char_data.value = char
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        # End of string
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
    
    # Send second list
    dut.str1_valid.value = 0
    dut.str2_valid.value = 1
    for string in list2:
        for i, char in enumerate(string.encode()):
            dut.char_data.value = char
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        # End of string
        dut.char_valid.value = 0
        await RisingEdge(dut.clk)
    
    # Wait for done
    for _ in range(100):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            break
    
    # Check results
    if not is_value_defined(dut.result_select.value):
        raise TestFailure("Result select undefined")
    
    result_select = int(dut.result_select.value)
    result_len = int(dut.result_len.value)
    
    if result_select != expected_select:
        raise TestFailure(f"Expected select {expected_select}, got {result_select}")
    if result_len != expected_len:
        raise TestFailure(f"Expected len {expected_len}, got {result_len}")
    
    cocotb.log.info(f"PASS: select={result_select}, len={result_len}")
