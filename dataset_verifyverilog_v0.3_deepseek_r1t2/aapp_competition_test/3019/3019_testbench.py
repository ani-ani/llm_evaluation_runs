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
    if value < 0:
        return from_signed(max(-((1 << (bits-1))), min((1 << (bits-1)) - 1, value)), bits)
    return min(max_val, max(0, value))

# Sequential helpers
async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=50000):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

# Main test
@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_max_revenue(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test cases: (description, N, S_list, expected_result)
    test_cases = [
        ('N=1, S=[1]', 1, [1], 0),
        ('N=3, S=[4,7,8]', 3, [4,7,8], 3),
        ('N=5, S=[2,3,4,5,8]', 5, [2,3,4,5,8], 5),
        ('N=10, S=[1,2,3,4,5,6,7,8,9,10]', 10, [1,2,3,4,5,6,7,8,9,10], 12),
    ]
    
    passed = 0
    failed = 0
    
    for desc, N, S_list, expected in test_cases:
        cocotb.log.info(f'Test: {desc}')
        
        # Set N
        dut.N.value = N
        
        # Set S_i values (only first N are used, set others to 0)
        for i in range(14):
            port_name = f'S_{i}'
            if has_signal(dut, port_name):
                if i < N:
                    val = S_list[i]
                    val_clamped = clamp_to_width(val, 10)
                    getattr(dut, port_name).value = val_clamped
                else:
                    getattr(dut, port_name).value = 0
            else:
                cocotb.log.error(f'Port {port_name} not found')
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        try:
            await wait_for_done(dut, max_cycles=50000)
        except TestFailure as e:
            cocotb.log.error(f'  FAIL: {e}')
            failed += 1
            continue
        
        # Read result
        if not is_value_defined(dut.result.value):
            cocotb.log.error(f'  FAIL: result is undefined')
            failed += 1
            continue
        
        result = int(dut.result.value)
        
        if result != expected:
            cocotb.log.error(f'  FAIL: expected {expected}, got {result}')
            failed += 1
        else:
            cocotb.log.info(f'  PASS: result = {result}')
            passed += 1
    
    cocotb.log.info(f'{'='*50}')
    cocotb.log.info(f'Results: {passed}/{passed+failed} tests passed')
    
    if failed > 0:
        raise TestFailure(f'{failed} tests failed')