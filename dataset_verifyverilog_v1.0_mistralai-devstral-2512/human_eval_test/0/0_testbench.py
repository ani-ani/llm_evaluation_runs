import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Constants
DATA_WIDTH = 16
ARRAY_SIZE = 8
CLK_NS = 10
MAX_CYCLES = 200

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Fixed point conversion (Q8.8)
def float_to_fixed(f, frac=8):
    return int(f * (1 << frac))

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    if has_signal(dut, 'we'): dut.we.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=100):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done after {max_cycles} cycles")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_has_close_elements(dut):
    # Setup clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational block
        await Timer(10, units='ns')

    # Test cases: (input_list, threshold_float, expected_result)
    test_cases = [
        ([1.0, 2.0, 3.0], 0.5, False),
        ([1.0, 2.8, 3.0, 4.0, 5.0, 2.0], 0.3, True),
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.3, True),
        ([1.0, 2.0, 3.9, 4.0, 5.0, 2.2], 0.05, False),
        ([1.0, 2.0, 5.9, 4.0, 5.0], 0.95, True),
        ([1.0, 2.0, 5.9, 4.0, 5.0], 0.8, False),
        ([1.0, 2.0, 3.0, 4.0, 5.0, 2.0], 0.1, True),
        ([1.1, 2.2, 3.1, 4.1, 5.1], 1.0, True),
        ([1.1, 2.2, 3.1, 4.1, 5.1], 0.5, False)
    ]

    passed = 0
    failed = 0

    for i, (numbers, thresh, expected) in enumerate(test_cases):
        # Pad input to ARRAY_SIZE with 0 if needed
        padded_nums = numbers + [0.0] * (ARRAY_SIZE - len(numbers))
        
        # Convert to fixed point
        fixed_nums = [float_to_fixed(x) for x in padded_nums]
        fixed_thresh = float_to_fixed(thresh)

        cocotb.log.info(f"Test {i+1}: Input {numbers}, Threshold {thresh}, Exp {expected}")

        try:
            if has_signal(dut, 'clk'):
                # 1. Load data sequentially
                dut.we.value = 1
                for idx, val in enumerate(fixed_nums):
                    dut.addr_in.value = idx
                    dut.data_in.value = val
                    await RisingEdge(dut.clk)
                
                dut.we.value = 0
                
                # 2. Set threshold and start
                dut.threshold.value = fixed_thresh
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0

                # 3. Wait for done
                await wait_for_done(dut, max_cycles=20)

                # 4. Check result
                result = int(dut.result.value)
                
                if result != int(expected):
                    raise TestFailure(f"Expected {int(expected)}, got {result}")
            
            else:
                # Combinational version
                # Set inputs directly
                for idx, val in enumerate(fixed_nums):
                    if hasattr(dut, f'arr_{idx}'):
                        getattr(dut, f'arr_{idx}').value = val
                    elif hasattr(dut, 'arr'):
                        # Array port access
                        if hasattr(dut.arr, '__getitem__'):
                             dut.arr[idx].value = val
                
                dut.threshold.value = fixed_thresh
                await Timer(10, units='ns')
                
                result = int(dut.result.value)
                if result != int(expected):
                     raise TestFailure(f"Expected {int(expected)}, got {result}")

            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"FAIL: {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed")
