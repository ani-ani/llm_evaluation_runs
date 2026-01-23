import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
MAX_POINTS = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 1000

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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
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
async def test_two_lines_cover(dut):
    'Test the TwoLinesCover module.'
    is_sequential = has_signal(dut, 'clk')
    if is_sequential:
        cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
        await reset_dut(dut)
    
    test_cases = [
        (6, [(-1,0), (0,0), (1,0), (-1,1), (0,2), (1,1)], 0),
        (6, [(1,1), (3,5), (0,-1), (1,0), (5,0), (0,0)], 1),
        (6, [(1,1), (3,5), (0,-1), (1,0), (5,0), (0,1)], 0),
        (6, [(6,1), (3,5), (0,-1), (1,0), (6,0), (0,0)], 0),
        (1, [(0,0)], 1),
        (2, [(0,0), (1,1)], 1),
        (3, [(0,0), (1,1), (2,2)], 1),
        (3, [(0,0), (1,0), (0,1)], 1),
        (4, [(0,0), (1,0), (0,1), (1,1)], 1),
        (4, [(0,0), (1,0), (0,1), (2,2)], 0),
    ]
    
    passed = 0
    failed = 0
    
    for i, (count, points, expected) in enumerate(test_cases):
        cocotb.log.info('Test ' + str(i+1) + ': count=' + str(count) + ', expected=' + ('success' if expected else 'failure'))
        try:
            if has_signal(dut, 'count'):
                dut.count.value = count
            else:
                raise TestFailure('Signal count not found')
            
            for idx, (x_val, y_val) in enumerate(points):
                if has_signal(dut, 'x'):
                    try:
                        dut.x[idx].value = from_signed(x_val, DATA_WIDTH)
                    except Exception:
                        raise TestFailure('Cannot assign x[' + str(idx) + ']')
                else:
                    raise TestFailure('Signal x not found')
                
                if has_signal(dut, 'y'):
                    try:
                        dut.y[idx].value = from_signed(y_val, DATA_WIDTH)
                    except Exception:
                        raise TestFailure('Cannot assign y[' + str(idx) + ']')
                else:
                    raise TestFailure('Signal y not found')
            
            for idx in range(len(points), MAX_POINTS):
                if has_signal(dut, 'x'):
                    dut.x[idx].value = 0
                if has_signal(dut, 'y'):
                    dut.y[idx].value = 0
            
            if is_sequential:
                await start_computation(dut)
                await wait_for_done(dut)
                if not is_value_defined(dut.success.value):
                    raise TestFailure('Success signal undefined')
                result = int(dut.success.value)
            else:
                await Timer(100, units='ns')
                if not is_value_defined(dut.success.value):
                    raise TestFailure('Success signal undefined')
                result = int(dut.success.value)
            
            if result != expected:
                raise TestFailure(f'Expected {expected}, got {result}')
            
            cocotb.log.info('  PASS')
            passed += 1
        except TestFailure as e:
            cocotb.log.error('  FAIL: ' + str(e))
            failed += 1
    
    cocotb.log.info('=' * 50)
    cocotb.log.info('Results: ' + str(passed) + '/' + str(passed+failed) + ' tests passed')
    if failed > 0:
        raise TestFailure(str(failed) + ' tests failed')