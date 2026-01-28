import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import math

# --- Helpers ---
def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def safe_int(v, default=0):
    try: return int(v)
    except ValueError: return default

def clamp_to_width(v, bits):
    max_val = (1 << bits) - 1
    if v < 0: return 0
    if v > max_val: return max_val
    return v

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

# --- Fixed Point Helpers ---
Q16_16_SCALE = 1 << 16

def float_to_q16_16(f):
    return int(f * Q16_16_SCALE)

def q16_16_to_float(v):
    # Handle signed values if applicable
    if v < 0:
        # Assuming unsigned in this specific problem, but good to have
        pass
    return v / Q16_16_SCALE

def dist_float(p1, p2):
    return math.sqrt((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2)

# --- DUT Interaction ---
async def setup_inputs(dut, a, b, conveyors):
    # Set Start/End
    dut.a_x.value = float_to_q16_16(a[0])
    dut.a_y.value = float_to_q16_16(a[1])
    dut.b_x.value = float_to_q16_16(b[0])
    dut.b_y.value = float_to_q16_16(b[1])
    
    count = len(conveyors)
    dut.conv_count.value = count
    
    # Set Conveyor inputs
    # Assuming dut has an array of inputs for simplicity in this testbench
    # or sequential loading. Here we assume a flattened interface for testing
    # dut.conv_x1[0], dut.conv_y1[0]...
    
    for i in range(min(count, 100)):
        c = conveyors[i]
        # Assuming signals exist like conv_x1_0, conv_y1_0, etc. or arrays
        if has_signal(dut, f'conv_x1_{i}'):
            getattr(dut, f'conv_x1_{i}').value = float_to_q16_16(c[0])
            getattr(dut, f'conv_y1_{i}').value = float_to_q16_16(c[1])
            getattr(dut, f'conv_x2_{i}').value = float_to_q16_16(c[2])
            getattr(dut, f'conv_y2_{i}').value = float_to_q16_16(c[3])
        elif has_signal(dut, 'conv_x1') and hasattr(dut.conv_x1, '__getitem__'):
            dut.conv_x1[i].value = float_to_q16_16(c[0])
            dut.conv_y1[i].value = float_to_q16_16(c[1])
            dut.conv_x2[i].value = float_to_q16_16(c[2])
            dut.conv_y2[i].value = float_to_q16_16(c[3])

async def reset_dut(dut):
    dut.rst_n.value = 0
    if has_signal(dut, 'start'): dut.start.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def wait_for_done(dut, max_cycles=20000):
    for _ in range(max_cycles):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
            return True
    raise TestFailure(f"Timeout after {max_cycles} cycles")

# --- Test Cases ---
TEST_CASES = [
    {
        "input": "60.0 0.0 50.0 170.0\n3\n40.0 0.0 0.0 0.0\n5.0 20.0 5.0 170.0\n95.0 0.0 95.0 80.0\n",
        "output": 168.7916512460
    },
    {
        "input": "60.0 0.0 50.0 170.0\n3\n40.0 0.0 0.0 0.0\n5.0 20.0 5.0 170.0\n95.0 0.0 95.0 100.0\n",
        "output": 163.5274740179
    },
    {
        "input": "0.0 1.0 4.0 1.0\n1\n0.0 0.0 4.0 0.0\n",
        "output": 3.7320508076
    }
]

def parse_test_input(input_str):
    lines = input_str.strip().split('\n')
    coords = list(map(float, lines[0].split()))
    n = int(lines[1])
    conveyors = []
    for i in range(n):
        c_coords = list(map(float, lines[2+i].split()))
        conveyors.append(c_coords)
    return (coords[0], coords[1]), (coords[2], coords[3]), conveyors

@cocotb.test(timeout_time=10, timeout_unit="s")
async def test_airport_conveyor(dut):
    # Setup Clock
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    passed = 0
    failed = 0
    
    for i, case in enumerate(TEST_CASES):
        a, b, conveyors = parse_test_input(case['input'])
        expected_time = case['output']
        
        cocotb.log.info(f"Running Test Case {i+1}: A={a}, B={b}, Conveyors={len(conveyors)}")
        
        try:
            await setup_inputs(dut, a, b, conveyors)
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            await wait_for_done(dut)
            
            if not is_value_defined(dut.result.value):
                raise TestFailure("Result signal undefined")
                
            result_val = int(dut.result.value)
            result_time = q16_16_to_float(result_val)
            
            # Allow absolute error of 10^-4
            error = abs(result_time - expected_time)
            
            if error > 1e-4:
                raise TestFailure(f"Result mismatch. Expected {expected_time:.10f}, got {result_time:.10f} (diff {error:.6f})")
            
            passed += 1
            
        except TestFailure as e:
            cocotb.log.error(f"Test {i+1} Failed: {e}")
            failed += 1
            
    if failed > 0:
        raise TestFailure(f"{failed} tests failed, {passed} passed")
