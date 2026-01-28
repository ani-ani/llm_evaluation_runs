import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    if v < 0: v = 0
    mask = (1 << bits) - 1
    return v & mask

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# Global constants
MAX_LIGHTS = 100
CLK_NS = 10
TIMEOUT_CYCLES = 1000

async def wait_for_done(dut):
    for _ in range(TIMEOUT_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout waiting for done signal")

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=2000, timeout_unit="ms")
async def test_lights_sim(dut):
    # Check if sequential
    is_seq = has_signal(dut, 'clk')
    if is_seq:
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)

    # Define test cases: (init_state_str, list of (a,b), expected_max_on)
    test_cases = [
        (
            "101",
            [(3,3), (3,2), (3,1)],
            2
        ),
        (
            "1111",
            [(3,4), (5,2), (3,1), (3,2)],
            4
        ),
        (
            "011100",
            [(5,3), (5,5), (2,4), (3,5), (4,2), (1,5)],
            6
        )
    ]

    passed = 0
    failed = 0

    for i, (init_str, params_list, expected) in enumerate(test_cases):
        n = len(init_str)
        cocotb.log.info(f"Running Test Case {i+1}: n={n}, expected={expected}")
        
        # Prepare inputs
        # init_state: vector of bits
        init_val = 0
        for idx, char in enumerate(init_str):
            if char == '1':
                init_val |= (1 << idx)
        
        # a and b arrays: packed into values for 100 lights
        # For this test, we only configure first 'n' lights, rest are 0
        a_val = 0
        b_val = 0
        for idx, (a, b) in enumerate(params_list):
            a_val |= (a << (3 * idx))
            b_val |= (b << (3 * idx))

        try:
            if is_seq:
                # Set inputs before start
                dut.init_state.value = init_val
                dut.a.value = a_val
                dut.b.value = b_val
                
                await RisingEdge(dut.clk)
                dut.start.value = 1
                await RisingEdge(dut.clk)
                dut.start.value = 0
                
                await wait_for_done(dut)
                
                # Read result
                if not is_value_defined(dut.max_on.value):
                    raise TestFailure("max_on is undefined")
                
                result = int(dut.max_on.value)
                
            else:
                # Combinational (just for safety, though design is sequential)
                dut.init_state.value = init_val
                dut.a.value = a_val
                dut.b.value = b_val
                await Timer(100, units='ns')
                result = int(dut.max_on.value) if is_value_defined(dut.max_on.value) else 0

            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            passed += 1
            cocotb.log.info(f"Test {i+1} PASSED")

        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} FAILED: {e}")
            failed += 1

    if failed:
        raise TestFailure(f"{failed} test(s) failed")
