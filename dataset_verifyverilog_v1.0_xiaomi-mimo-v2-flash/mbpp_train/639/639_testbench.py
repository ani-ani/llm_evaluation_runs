import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

# Write names to dut
async def write_names(dut, names_list, num_names=6):
    for name_idx in range(num_names):
        if name_idx < len(names_list):
            name = names_list[name_idx]
            # Pad to exactly 8 bytes with null (0x00) termination
            padded = (name + '\x00' * 8)[:8]
        else:
            # Empty name (all null)
            padded = '\x00' * 8
        
        for char_idx in range(8):
            val = ord(padded[char_idx])
            signal = getattr(dut, f'names_{name_idx}_{char_idx}')
            signal.value = clamp_to_width(val, 8)

# Reset sequence
async def reset_dut(dut):
    if has_signal(dut, 'rst_n'):
        dut.rst_n.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

@cocotb.test(timeout_time=100, timeout_unit='ms')
async def test_filter_sum(dut):
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    # Test case 1
    names1 = ['sally', 'Dylan', 'rebecca', 'Diana', 'Joanne', 'keith']
    await write_names(dut, names1)
    if has_signal(dut, 'len'):
        dut.len.value = len(names1)
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    expected = 16
    if result != expected:
        raise TestFailure(f"Test 1: Expected {expected}, got {result}")
    
    # Test case 2
    names2 = ['php', 'res', 'Python', 'abcd', 'Java', 'aaa']
    await write_names(dut, names2)
    if has_signal(dut, 'len'):
        dut.len.value = len(names2)
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    expected = 10
    if result != expected:
        raise TestFailure(f"Test 2: Expected {expected}, got {result}")
    
    # Test case 3
    names3 = ['abcd', 'Python', 'abba', 'aba']
    await write_names(dut, names3)
    if has_signal(dut, 'len'):
        dut.len.value = len(names3)
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    expected = 6
    if result != expected:
        raise TestFailure(f"Test 3: Expected {expected}, got {result}")
    
    # Additional test: empty names
    names4 = []
    await write_names(dut, names4)
    if has_signal(dut, 'len'):
        dut.len.value = 0
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    expected = 0
    if result != expected:
        raise TestFailure(f"Test 4 (empty): Expected {expected}, got {result}")
    
    # Edge case: uppercase but middle uppercase
    names5 = ['DyLan']
    await write_names(dut, names5)
    if has_signal(dut, 'len'):
        dut.len.value = 1
    
    if is_seq and has_signal(dut, 'start'):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        for _ in range(100):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
    else:
        await Timer(100, units='ns')
    
    result = int(dut.result.value)
    expected = 0  # 'y' is uppercase, not allowed
    if result != expected:
        raise TestFailure(f"Test 5 (mixed case): Expected {expected}, got {result}")