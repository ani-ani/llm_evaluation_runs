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
    for i, val in enumerate(values):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            getattr(dut, port_name).value = clamp_to_width(val, element_width)
        else:
            try:
                arr = getattr(dut, array_name)
                arr[i].value = clamp_to_width(val, element_width)
            except (AttributeError, TypeError):
                raise TestFailure(f'Cannot find array port: {array_name}[{i}] or {port_name}')

async def read_array(dut, array_name, size):
    results = []
    for i in range(size):
        port_name = f'{array_name}_{i}'
        if has_signal(dut, port_name):
            val = getattr(dut, port_name).value
            if is_value_defined(val):
                results.append(int(val))
            else:
                results.append(None)
        else:
            try:
                arr = getattr(dut, array_name)
                if is_value_defined(arr[i].value):
                    results.append(int(arr[i].value))
                else:
                    results.append(None)
            except (AttributeError, TypeError):
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
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_robber_password(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        ('car', 1),
        ('cocar', 2),
        ('cocaror', 4),
    ]
    
    passed = 0
    failed = 0
    
    for i, (pwd, expected) in enumerate(test_cases):
        dut._log.info(f'Test {i+1}: encrypted={pwd}, expected={expected}')
        
        values = [ord(c) for c in pwd]
        length = len(values)
        padded_values = values + [0] * (16 - length)
        
        await write_array(dut, 'arr', padded_values, 8)
        
        if has_signal(dut, 'length'):
            dut.length.value = length
        else:
            raise TestFailure('Signal length not found')
        
        if is_sequential:
            await start_computation(dut)
            await wait_for_done(dut, max_cycles=1000)
        else:
            await Timer(100, units='ns')
        
        if not is_value_defined(dut.result.value):
            raise TestFailure('Result is undefined (X/Z)')
        
        result = int(dut.result.value)
        
        if result != expected:
            dut._log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            dut._log.info(f'  PASS: result = {result}')
            passed += 1
    
    dut._log.info('='*50)
    dut._log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')