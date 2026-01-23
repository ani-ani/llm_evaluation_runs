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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f'Timeout: done not asserted after {max_cycles} cycles')

@cocotb.test(timeout_time=5000, timeout_unit='ms')
async def test_optimal_cache(dut):
    '''Test the optimal cache module.'''
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    # Reset
    await reset_dut(dut)
    
    # Define test cases: (c, a, accesses, expected_misses)
    test_cases = [
        (1, 3, [0, 0, 1], 2),
        (3, 8, [0, 1, 2, 3, 3, 2, 1, 0], 5),
    ]
    
    for c, a, accesses, expected in test_cases:
        dut._log.info(f'Running test case: c={c}, a={a}, accesses={accesses}')
        
        # Write the access sequence into the DUT's sequence memory
        for i, obj in enumerate(accesses):
            # Clamp object to 4 bits (though test values are small)
            obj_clamped = clamp_to_width(obj, 4)
            dut.obj_addr.value = i
            dut.obj_data.value = obj_clamped
            dut.obj_write.value = 1
            await RisingEdge(dut.clk)
            dut.obj_write.value = 0
            await RisingEdge(dut.clk)  # Ensure write is complete
        
        # Set cache size and number of accesses
        dut.c.value = c
        dut.a.value = a
        await RisingEdge(dut.clk)
        
        # Pulse start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        await wait_for_done(dut, max_cycles=5000)
        
        # Read miss_count
        miss_count = int(dut.miss_count.value)
        if miss_count != expected:
            raise TestFailure(f'Expected {expected} misses, got {miss_count}')
        else:
            dut._log.info(f'  PASS: misses = {miss_count}')
    
    dut._log.info('All tests passed!')