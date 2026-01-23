import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 16
ARRAY_SIZE = 16
RESULT_WIDTH = 16
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

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for cycle in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout: done not asserted after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_zebra_divider(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ("00101000", True, [[1], [2,3,4,5,6], [7], [8]]),
        ("11111111", False, []),
        ("01010101", False, []),
        ("0", True, [[1]]),
        ("01000000", True, [[1,2,3], [4], [5], [6], [7], [8]]),
    ]
    
    for test_str, expected_valid, expected_zebras in test_cases:
        dut._log.info(f"Testing string: {test_str}")
        
        # Convert string to bit vector
        bit_vec = 0
        for i, char in enumerate(test_str):
            if char == '1':
                bit_vec |= (1 << i)
        
        dut.s.value = bit_vec
        dut.length.value = len(test_str)
        
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        await wait_for_done(dut)
        
        if not is_value_defined(dut.valid.value):
            raise TestFailure("Valid signal is undefined")
        
        actual_valid = int(dut.valid.value)
        
        if actual_valid != expected_valid:
            raise TestFailure(f"Valid mismatch: expected {expected_valid}, got {actual_valid}")
        
        if expected_valid:
            k = int(dut.k.value)
            if k != len(expected_zebras):
                raise TestFailure(f"Number of zebras mismatch: expected {len(expected_zebras)}, got {k}")
            
            for i in range(k):
                actual_length = int(dut.zebra_length[i].value)
                expected_length = len(expected_zebras[i])
                if actual_length != expected_length:
                    raise TestFailure(f"Zebra {i} length mismatch: expected {expected_length}, got {actual_length}")
                
                for j in range(expected_length):
                    actual_idx = int(dut.zebra_indices[i][j].value)
                    expected_idx = expected_zebras[i][j]
                    if actual_idx != expected_idx:
                        raise TestFailure(f"Zebra {i} index {j} mismatch: expected {expected_idx}, got {actual_idx}")
            
            dut._log.info(f"  PASS: {k} zebras")
        else:
            dut._log.info(f"  PASS: correctly detected invalid")
