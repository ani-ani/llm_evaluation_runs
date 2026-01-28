import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helpers
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

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=1000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_ranger_op(dut):
    # Clock setup
    clk_period = 10  # ns
    cocotb.start_soon(Clock(dut.clk, clk_period, units='ns').start())
    await reset_dut(dut)

    # Test cases: (n, k, x, arr, expected_max, expected_min)
    test_cases = [
        (5, 1, 2, [9, 7, 11, 15, 5], 13, 7),
        (2, 1, 569, [605, 986], 986, 605),
        (1, 1, 1, [1], 1, 1),
        (3, 2, 5, [1, 2, 3], 7, 1),
        (4, 3, 2, [0, 4, 1, 4], 6, 0)
    ]

    passed = 0
    failed = 0

    for i, (n_val, k_val, x_val, arr_vals, exp_max, exp_min) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: n={n_val}, k={k_val}, x={x_val}, arr={arr_vals}")
        
        try:
            # Initialize inputs
            dut.n_in.value = n_val
            dut.k_in.value = k_val
            dut.x_in.value = x_val
            
            # Load array values - handle both packed array and individual signals
            if has_signal(dut, 'arr_in'):
                if hasattr(dut.arr_in, '__len__'):
                    # Array of signals
                    for j in range(min(n_val, len(dut.arr_in))):
                        dut.arr_in[j].value = clamp_to_width(arr_vals[j], 10)
                else:
                    # Packed array - not typical for 8x10, but handle if present
                    # Assuming 8-element array interface
                    pass
            else:
                # Check for individual arr_in_0, arr_in_1...
                for j in range(n_val):
                    signal_name = f'arr_in_{j}'
                    if has_signal(dut, signal_name):
                        getattr(dut, signal_name).value = clamp_to_width(arr_vals[j], 10)

            # Start the operation
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            # Wait for done
            await wait_for_done(dut)
            
            # Read outputs
            if not is_value_defined(dut.max_out.value) or not is_value_defined(dut.min_out.value):
                raise TestFailure("Output values undefined")
            
            result_max = int(dut.max_out.value)
            result_min = int(dut.min_out.value)
            
            if result_max != exp_max or result_min != exp_min:
                raise TestFailure(f"Expected max={exp_max}, min={exp_min}, got max={result_max}, min={result_min}")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"FAIL (Test {i+1}): {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
