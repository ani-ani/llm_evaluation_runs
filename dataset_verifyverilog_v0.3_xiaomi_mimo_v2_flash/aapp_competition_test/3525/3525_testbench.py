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

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_badge_access_counter(dut):
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
        dut.rst_n.value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        for _ in range(2):
            await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    test_cases = [
        {
            'S': 2,
            'D': 1,
            'lock_count': 5,
            'badge_max': 10,
            'locks': [
                0x00010407,
                0x02000106,
                0x0203070A,
                0x01030305,
                0x03010809,
            ],
            'expected': 5,
        },
        {
            'S': 0,
            'D': 3,
            'lock_count': 5,
            'badge_max': 9,
            'locks': [
                0x00010305,
                0x00020607,
                0x00030203,
                0x01030406,
                0x02030709,
            ],
            'expected': 5,
        },
    ]
    for test_idx, tc in enumerate(test_cases):
        cocotb.log.info(f'Running test case {test_idx+1}')
        dut.S.value = tc['S']
        dut.D.value = tc['D']
        dut.lock_count.value = tc['lock_count']
        dut.badge_max.value = tc['badge_max']
        for i in range(16):
            if i < tc['lock_count']:
                getattr(dut, f'lock{i}').value = tc['locks'][i]
            else:
                getattr(dut, f'lock{i}').value = 0
        if has_signal(dut, 'start'):
            dut.start.value = 0
        if is_sequential:
            await RisingEdge(dut.clk)
        if has_signal(dut, 'start'):
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
        else:
            await Timer(100, units='ns')
        if is_sequential:
            for _ in range(1000):
                await RisingEdge(dut.clk)
                if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                    break
            else:
                raise TestFailure(f'Test {test_idx+1}: Timeout waiting for done')
        else:
            await Timer(100, units='ns')
        if not is_value_defined(dut.result.value):
            raise TestFailure(f'Test {test_idx+1}: Result is undefined')
        result = int(dut.result.value)
        expected = tc['expected']
        if result != expected:
            raise TestFailure(f'Test {test_idx+1}: Expected {expected}, got {result}')
        cocotb.log.info(f'Test {test_idx+1} passed: result = {result}')
    cocotb.log.info('All tests passed')