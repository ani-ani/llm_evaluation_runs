import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
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

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_add_nested_tuples(dut):
    DATA_WIDTH = 8
    ROWS = 4
    COLS = 2
    CLK_NS = 10
    MAX_CYCLES = 100
    
    # Setup clock
    cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test cases
    test_cases = [
        {
            'a': [[1, 3], [4, 5], [2, 9], [1, 10]],
            'b': [[6, 7], [3, 9], [1, 1], [7, 3]],
            'expected': [[7, 10], [7, 14], [3, 10], [8, 13]],
            'desc': 'Test 1'
        },
        {
            'a': [[2, 4], [5, 6], [3, 10], [2, 11]],
            'b': [[7, 8], [4, 10], [2, 2], [8, 4]],
            'expected': [[9, 12], [9, 16], [5, 12], [10, 15]],
            'desc': 'Test 2'
        },
        {
            'a': [[3, 5], [6, 7], [4, 11], [3, 12]],
            'b': [[8, 9], [5, 11], [3, 3], [9, 5]],
            'expected': [[11, 14], [11, 18], [7, 14], [12, 17]],
            'desc': 'Test 3'
        }
    ]
    
    for tc in test_cases:
        cocotb.log.info(f"Running {tc['desc']}")
        
        # Write array inputs (individual element assignment as required)
        for r in range(ROWS):
            for c in range(COLS):
                # Access a as a_0, a_1... or nested if your HDL supports
                # Assuming flattened port a_0_0, a_0_1, a_1_0... or array
                # We'll try array access first, fallback to individual
                try:
                    dut.a[r][c].value = clamp_to_width(tc['a'][r][c], DATA_WIDTH)
                    dut.b[r][c].value = clamp_to_width(tc['b'][r][c], DATA_WIDTH)
                except (AttributeError, TypeError):
                    # Fallback: Individual ports like a_0_0
                    port_name = f'a_{r}_{c}'
                    getattr(dut, port_name).value = clamp_to_width(tc['a'][r][c], DATA_WIDTH)
                    port_name = f'b_{r}_{c}'
                    getattr(dut, port_name).value = clamp_to_width(tc['b'][r][c], DATA_WIDTH)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (max 10 cycles)
        done = False
        for _ in range(10):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                done = True
                break
        
        if not done:
            raise TestFailure(f"{tc['desc']}: Done signal not asserted within 10 cycles")
        
        # Verify results
        for r in range(ROWS):
            for c in range(COLS):
                try:
                    result_val = int(getattr(dut, f'result_{r}_{c}').value)
                except AttributeError:
                    result_val = int(dut.result[r][c].value)
                expected = tc['expected'][r][c]
                if result_val != expected:
                    raise TestFailure(f"{tc['desc']}: result[{r}][{c}] = {result_val}, expected {expected}")
    
    cocotb.log.info("All tests passed!")