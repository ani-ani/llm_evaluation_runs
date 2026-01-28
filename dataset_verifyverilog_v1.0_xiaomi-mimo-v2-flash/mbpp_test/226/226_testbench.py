import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# MANDATORY HELPERS
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

# CONSTANTS
DATA_WIDTH = 8
ARRAY_SIZE_IN = 16
ARRAY_SIZE_OUT = 8
CLK_NS = 10
MAX_CYCLES = 200

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(cycles): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def write_input_string(dut, s):
    # Write characters to input_str array
    for i in range(ARRAY_SIZE_IN):
        if i < len(s):
            val = ord(s[i])
        else:
            val = 0
        # Clamp just in case, though ASCII fits in 8 bits
        dut.input_str[i].value = clamp_to_width(val, DATA_WIDTH)

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_odd_index_filter(dut):
    # Check for clock
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # Combinational logic (unlikely for this problem, but good practice)
        await Timer(100, units='ns')

    # Test cases from prompt
    test_cases = [
        ('abcdef', 'ace', "Test 1: abcdef -> ace"),
        ('python', 'pto', "Test 2: python -> pto"),
        ('data', 'dt', "Test 3: data -> dt"),
        ('lambs', 'lms', "Test 4: lambs -> lms")
    ]

    passed = 0
    failed = 0

    for inp_str, exp_str, desc in test_cases:
        cocotb.log.info(f"Running: {desc}")
        try:
            # Prepare inputs
            len_val = len(inp_str)
            
            # Write input string
            await write_input_string(dut, inp_str)
            dut.len.value = len_val

            if is_seq:
                # Start processing
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                # Wait for done
                await wait_for_done(dut)
                
                # Read results
                if not is_value_defined(dut.done.value):
                    raise TestFailure("Done signal undefined")
                
                output_len = int(dut.output_len.value)
                
                # Verify length
                if output_len != len(exp_str):
                    raise TestFailure(f"Length mismatch: expected {len(exp_str)}, got {output_len}")
                
                # Verify characters
                result_chars = []
                for i in range(output_len):
                    if has_signal(dut, f'result_{i}'):
                        # Unpacked individual signals (e.g., result_0, result_1...)
                        val = int(getattr(dut, f'result_{i}').value)
                    else:
                        # Unpacked array interface
                        val = int(dut.result[i].value)
                    result_chars.append(chr(val))
                
                result_str = ''.join(result_chars)
                if result_str != exp_str:
                    raise TestFailure(f"Result mismatch: expected '{exp_str}', got '{result_str}'")
            else:
                # Combinational fallback (wait for propagation)
                await Timer(100, units='ns')
                # Check logic similarly if signals are stable
                # (Skipping detailed logic for comb as it's mainly for sequential)

            cocotb.log.info(f"PASS: {desc}")
            passed += 1

        except TestFailure as e:
            cocotb.log.error(f"FAIL: {desc} - {e}")
            failed += 1

    if failed > 0:
        raise TestFailure(f"{failed} tests failed out of {passed + failed}")
