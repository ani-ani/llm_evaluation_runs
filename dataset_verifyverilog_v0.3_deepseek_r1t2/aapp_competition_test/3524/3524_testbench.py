import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def to_signed(val, bits):
    if val >= (1 << (bits - 1)):
        return val - (1 << bits)
    return val

def from_signed(val, bits):
    if val < 0:
        return val + (1 << bits)
    return val

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

async def write_array(dut, array_name, values, element_width):
    try:
        arr = getattr(dut, array_name)
        for i, val in enumerate(values):
            arr[i].value = clamp_to_width(val, element_width)
        return
    except (AttributeError, TypeError):
        pass
    for i, val in enumerate(values):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            raise TestFailure(f"Cannot find array port: {array_name}[{i}] or {port_name}")

async def read_array(dut, array_name, size):
    results = []
    try:
        arr = getattr(dut, array_name)
        for i in range(size):
            if is_value_defined(arr[i].value):
                results.append(int(arr[i].value))
            else:
                results.append(None)
        return results
    except (AttributeError, TypeError):
        pass
    for i in range(size):
        port_name = f"{array_name}_{i}"
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            results.append(None)
    return results

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_interleaving_checker(dut):
    is_sequential = has_signal(dut, 'clk') and has_signal(dut, 'done')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    def pack_string(s):
        vec = 0
        for i, char in enumerate(s):
            vec |= (ord(char) << (8 * i))
        return vec
    
    test_cases = [
        ("aabcad", "aba", "acd", True),
        ("aabcad", "acb", "aad", False),
        ("aabcad", "acb", "acd", False),
    ]
    
    for i, (s_str, s1_str, s2_str, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: s='{s_str}', s1='{s1_str}', s2='{s2_str}'")
        s_vec = pack_string(s_str)
        s1_vec = pack_string(s1_str)
        s2_vec = pack_string(s2_str)
        len_s1 = len(s1_str)
        len_s2 = len(s2_str)
        
        if has_signal(dut, 's'):
            dut.s.value = s_vec
        if has_signal(dut, 's1'):
            dut.s1.value = s1_vec
        if has_signal(dut, 's2'):
            dut.s2.value = s2_vec
        if has_signal(dut, 'len_s1'):
            dut.len_s1.value = len_s1
        if has_signal(dut, 'len_s2'):
            dut.len_s2.value = len_s2
        
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut)
            if not is_value_defined(dut.result.value):
                raise TestFailure(f"Result is undefined")
            result = int(dut.result.value) == 1
        else:
            await Timer(100, units='ns')
            result = int(dut.result.value) == 1
        
        if result != expected:
            raise TestFailure(f"Test {i+1}: expected {expected}, got {result}")
        else:
            cocotb.log.info(f"  PASS")
    
    cocotb.log.info("All tests passed")