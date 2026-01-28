import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

DATA_WIDTH = 8
ARRAY_SIZE_STR = 8
ARRAY_SIZE_LIST = 4
CLK_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(v):
    try:
        int(v)
        return True
    except ValueError:
        return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def wait_for_done(dut, max_cycles=MAX_CYCLES):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

async def reset_dut(dut, cycles=2):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'):
        dut.start.value = 0
    for _ in range(cycles):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

# Helper to set tuple inputs
def set_tuple_inputs(dut, tuplex_str, tuplex_int, tuplex_list, tuplex_bool, m, n):
    # Set String (ASCII bytes)
    str_bytes = tuplex_str.encode('ascii').ljust(ARRAY_SIZE_STR, b'\x00')
    for i in range(ARRAY_SIZE_STR):
        dut.__getattr__(f'tuplex_str_{i}').value = str_bytes[i]
    
    # Set Integer
    dut.tuplex_int.value = clamp_to_width(tuplex_int, DATA_WIDTH)
    
    # Set List
    for i in range(ARRAY_SIZE_LIST):
        dut.__getattr__(f'tuplex_list_{i}').value = clamp_to_width(tuplex_list[i], DATA_WIDTH)
    
    # Set Boolean
    dut.tuplex_bool.value = tuplex_bool
    
    # Set Index and Value
    dut.m.value = m
    dut.n.value = clamp_to_width(n, DATA_WIDTH)

# Helper to check results
def check_results(dut, exp_str, exp_int, exp_list, exp_bool):
    # Check String
    res_str = ""
    for i in range(ARRAY_SIZE_STR):
        val = int(dut.__getattr__(f'result_str_{i}').value)
        if val != 0:
            res_str += chr(val)
    if res_str.strip() != exp_str.strip():
        raise TestFailure(f"String mismatch. Exp: '{exp_str}', Got: '{res_str}'")
    
    # Check Integer
    res_int = int(dut.result_int.value)
    if res_int != exp_int:
        raise TestFailure(f"Integer mismatch. Exp: {exp_int}, Got: {res_int}")
    
    # Check List
    res_list = [int(dut.__getattr__(f'result_list_{i}').value) for i in range(ARRAY_SIZE_LIST)]
    if res_list != exp_list:
        raise TestFailure(f"List mismatch. Exp: {exp_list}, Got: {res_list}")
    
    # Check Boolean
    res_bool = int(dut.result_bool.value)
    if res_bool != exp_bool:
        raise TestFailure(f"Boolean mismatch. Exp: {exp_bool}, Got: {res_bool}")

@cocotb.test(timeout_time=5000, timeout_unit="ms")
async def test_colon_tuplex(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        # If no clock, assume combinational and just wait a bit for propagation
        await Timer(100, units='ns')

    # Define Test Cases based on Python examples
    # Python: colon_tuplex(("HELLO", 5, [], True), 2, 50) -> ("HELLO", 5, [50], True)
    test_cases = [
        {
            "input": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [0, 0, 0, 0], # Simulating empty list as [0,0,0,0] initially
                "tuplex_bool": True,
                "m": 2,
                "n": 50
            },
            "expected": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [0, 0, 0, 50], # Append logic: shift 0,0,0 -> 0,0,0; append 50
                "tuplex_bool": True
            }
        },
        {
            "input": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [1, 2, 3, 4], # Non-empty list
                "tuplex_bool": True,
                "m": 2,
                "n": 100
            },
            "expected": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [2, 3, 4, 100], # Shift and append
                "tuplex_bool": True
            }
        },
        {
            "input": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [10, 20, 30, 40],
                "tuplex_bool": True,
                "m": 0, # Invalid index for append in this logic
                "n": 500
            },
            "expected": {
                "tuplex_str": "HELLO",
                "tuplex_int": 5,
                "tuplex_list": [10, 20, 30, 40], # No change
                "tuplex_bool": True
            }
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Set inputs
        set_tuple_inputs(
            dut,
            tc["input"]["tuplex_str"],
            tc["input"]["tuplex_int"],
            tc["input"]["tuplex_list"],
            tc["input"]["tuplex_bool"],
            tc["input"]["m"],
            tc["input"]["n"]
        )

        if is_seq:
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            await wait_for_done(dut)
        else:
            await Timer(100, units='ns')
        
        # Verify results
        try:
            check_results(
                dut,
                tc["expected"]["tuplex_str"],
                tc["expected"]["tuplex_int"],
                tc["expected"]["tuplex_list"],
                tc["expected"]["tuplex_bool"]
            )
            cocotb.log.info(f"Test Case {i+1} Passed")
        except TestFailure as e:
            cocotb.log.error(f"Test Case {i+1} Failed: {e}")
            raise