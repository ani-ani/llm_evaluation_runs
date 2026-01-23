import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# CONFIGURATION
DATA_WIDTH = 8
ARRAY_SIZE = 8
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# HELPER FUNCTIONS

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

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

# ARRAY WRITE

def write_array_individual(dut, values, element_width):
    for i in range(ARRAY_SIZE):
        port_name = f'arr_{i}'
        if i < len(values):
            val = values[i]
            val_unsigned = from_signed(val, element_width)
            getattr(dut, port_name).value = clamp_to_width(val_unsigned, element_width)
        else:
            getattr(dut, port_name).value = 0

# RESET and DONE

async def reset_dut(dut):
    dut.rst_n.value = 0
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

async def start_computation(dut):
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0

# MAIN TEST

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_find_negatives(dut):
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    await reset_dut(dut)
    
    test_cases = [
        ([-1, 4, 5, -6], [-1, -6]),
        ([-1, -2, 3, 4], [-1, -2]),
        ([-7, -6, 8, 9], [-7, -6]),
    ]
    
    passed = 0
    failed = 0
    
    for i, (input_list, expected) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: Input {input_list} -> Expected {expected}")
        
        try:
            write_array_individual(dut, input_list, DATA_WIDTH)
            dut.len.value = len(input_list)
            
            await RisingEdge(dut.clk)
            await start_computation(dut)
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result_len.value):
                raise TestFailure("result_len is undefined")
                
            result_len = int(dut.result_len.value)
            
            results = []
            for j in range(ARRAY_SIZE):
                port_name = f'result_{j}'
                if has_signal(dut, port_name):
                    val = getattr(dut, port_name).value
                    if is_value_defined(val):
                        results.append(to_signed(int(val), DATA_WIDTH))
            
            actual = results[:result_len]
            
            if len(actual) != len(expected):
                raise TestFailure(f"Length mismatch: got {len(actual)}, expected {len(expected)}")
            
            for j, (a, e) in enumerate(zip(actual, expected)):
                if a != e:
                    raise TestFailure(f"Index {j}: got {a}, expected {e}")
            
            cocotb.log.info(f"  PASS: {actual}")
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    if failed > 0:
        raise TestFailure(f"{failed} tests failed")