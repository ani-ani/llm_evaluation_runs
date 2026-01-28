import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure
import random

# Constants based on Verilog spec
MAX_ENERGY = 2048
CLK_NS = 10

def is_value_defined(v):
    try: int(v); return True
    except ValueError: return False

def clamp_to_width(v, bits):
    return min((1 << bits) - 1, max(0, v))

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.start.value = 0
    for _ in range(2): await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_polly_finder(dut):
    # Setup Clock
    if has_signal(dut, 'clk'):
        cocotb.start_soon(Clock(dut.clk, CLK_NS, units='ns').start())
        await reset_dut(dut)
    else:
        await Timer(100, units='ns')

    # Test cases mapping to scaled values (P=0.5 -> 128, 1.0 -> 255)
    # Input 1: 2 boxes, P=0.5. Box1: E=2, P=0.5. Box2: E=1, P=0.5.
    # Min energy: Open Box2 (E=1, P=0.5) -> Result 1.
    # Scaled: p=128, P_target=128. e=[2,1].
    test_cases = [
        {
            'e': [2, 1, 0, 0, 0, 0, 0, 0],
            'p': [128, 128, 0, 0, 0, 0, 0, 0],
            'P_target': 128,
            'expected': 1
        },
        # Input 2: Box1: E=2, P=0.51 (130). Box2: E=1, P=0.49 (125).
        # Total P needed 128. Cannot use just Box2 (125 < 128). 
        # Must use Box1 (130 >= 128) -> E=2.
        # Or both: E=3, P=255. Min is 2.
        {
            'e': [2, 1, 0, 0, 0, 0, 0, 0],
            'p': [130, 125, 0, 0, 0, 0, 0, 0],
            'P_target': 128,
            'expected': 2
        },
        # Input 3: P=1.0 (255). Box1: 0.3291 (84). Box2: 0.6709 (171).
        # Sum = 255. E=2+5=7.
        {
            'e': [2, 5, 0, 0, 0, 0, 0, 0],
            'p': [84, 171, 0, 0, 0, 0, 0, 0],
            'P_target': 255,
            'expected': 7
        }
    ]

    for i, tc in enumerate(test_cases):
        cocotb.log.info(f"Running Test Case {i+1}")
        
        # Apply inputs
        for j in range(8):
            getattr(dut, f'e_{j}').value = tc['e'][j]
            getattr(dut, f'p_{j}').value = tc['p'][j]
        dut.P_target.value = tc['P_target']
        
        # Start pulse
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout_cycles = 2000
        found_done = False
        for _ in range(timeout_cycles):
            await RisingEdge(dut.clk)
            if has_signal(dut, 'done') and is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                found_done = True
                break
        
        if not found_done:
            raise TestFailure(f"Test {i+1}: Timeout waiting for done signal")
            
        # Check result
        if not has_signal(dut, 'result'):
            raise TestFailure(f"Test {i+1}: Result signal missing")
            
        result_val = int(dut.result.value)
        expected_val = tc['expected']
        
        if result_val != expected_val:
            raise TestFailure(f"Test {i+1}: Expected {expected_val}, got {result_val}")
        
        cocotb.log.info(f"Test {i+1} Passed: Result {result_val}")
        
        # Small delay between tests
        await Timer(100, units='ns')
