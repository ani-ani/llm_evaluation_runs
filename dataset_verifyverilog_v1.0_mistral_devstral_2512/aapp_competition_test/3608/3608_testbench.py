import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Helper functions
def is_value_defined(value):
    try: int(value); return True
    except ValueError: return False

def has_signal(dut, name):
    try: getattr(dut, name); return True
    except AttributeError: return False

def clamp_to_width(value, bits):
    return min((1 << bits) - 1, max(0, value))

async def write_array(dut, name, values, width):
    for i, val in enumerate(values):
        getattr(dut, name)[i].value = clamp_to_width(val, width)

async def reset_dut(dut):
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_task_selection(dut):
    # Detect interface
    if not (has_signal(dut, 'clk') and has_signal(dut, 'done')):
        raise TestFailure("Module must be sequential with clk and done")
    
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    await reset_dut(dut)
    
    # Test cases (adapted for N=4)
    test_cases = [
        ([1, 5, 3, 0], [0, 2, 1], 33, "N=4 sample"),
        ([3, 0, 1, 0], [0, 1, 0], 3, "N=3 padded to N=4"),
    ]
    
    for i, (A_vals, B_vals, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        await write_array(dut, 'A', A_vals, 32)
        await write_array(dut, 'B', B_vals, 32)
        
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for _ in range(1000):
            await RisingEdge(dut.clk)
            if is_value_defined(dut.done.value) and int(dut.done.value) == 1:
                break
        else:
            raise TestFailure(f"Timeout for {desc}")
        
        if not is_value_defined(dut.result.value):
            raise TestFailure(f"Result undefined for {desc}")
        
        result = int(dut.result.value)
        if result != expected:
            raise TestFailure(f"{desc}: expected {expected}, got {result}")
        
        cocotb.log.info(f"  PASS: result = {result}")
        await RisingEdge(dut.clk)  # Wait for done to clear
