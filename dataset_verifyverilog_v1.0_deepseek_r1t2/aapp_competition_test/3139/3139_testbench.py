import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

# Configuration
DATA_WIDTH = 32
INDEX_WIDTH = 4
MAX_STUDENTS = 16
CLK_PERIOD_NS = 10
MAX_CYCLES = 100

# Helper functions
def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def safe_int(value, default=0):
    try:
        return int(value)
    except ValueError:
        return default

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

async def reset_dut(dut):
    dut.rst_n.value = 0
    dut.valid_in.value = 0
    for _ in range(2):
        await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

async def send_d_operation(dut, A, B):
    dut.valid_in.value = 1
    dut.op.value = 0
    dut.A_in.value = A
    dut.B_in.value = B
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0

async def send_p_operation(dut, idx):
    dut.valid_in.value = 1
    dut.op.value = 1
    dut.idx_in.value = idx
    await RisingEdge(dut.clk)
    dut.valid_in.value = 0
    
    # Wait for valid_out
    for _ in range(MAX_CYCLES):
        await RisingEdge(dut.clk)
        if is_value_defined(dut.valid_out.value) and int(dut.valid_out.value) == 1:
            return int(dut.result.value)
    raise TestFailure(f"Timeout waiting for valid_out for query P {idx}")

@cocotb.test(timeout_time=1000, timeout_unit="ms")
async def test_exam_helper(dut):
    # Start clock
    cocotb.start_soon(Clock(dut.clk, CLK_PERIOD_NS, units='ns').start())
    
    # Reset
    await reset_dut(dut)
    
    # Test case from problem
    # D 8 8 -> student 1
    # D 2 4 -> student 2  
    # D 5 6 -> student 3
    # P 2 -> should return 3
    # D 6 2 -> student 4
    # P 4 -> should return 1
    
    cocotb.log.info("Adding student 1: A=8, B=8")
    await send_d_operation(dut, 8, 8)
    
    cocotb.log.info("Adding student 2: A=2, B=4")
    await send_d_operation(dut, 2, 4)
    
    cocotb.log.info("Adding student 3: A=5, B=6")
    await send_d_operation(dut, 5, 6)
    
    cocotb.log.info("Query P 2 (student 2: A=2, B=4)")
    result = await send_p_operation(dut, 2)
    cocotb.log.info(f"Result: {result} (expected 3)")
    if result != 3:
        raise TestFailure(f"Expected 3, got {result}")
    
    cocotb.log.info("Adding student 4: A=6, B=2")
    await send_d_operation(dut, 6, 2)
    
    cocotb.log.info("Query P 4 (student 4: A=6, B=2)")
    result = await send_p_operation(dut, 4)
    cocotb.log.info(f"Result: {result} (expected 1)")
    if result != 1:
        raise TestFailure(f"Expected 1, got {result}")
    
    # Test case where no one can help
    await reset_dut(dut)
    cocotb.log.info("\nTest case 2: No valid helper")
    await send_d_operation(dut, 3, 1)
    await send_d_operation(dut, 2, 2)
    await send_d_operation(dut, 1, 3)
    
    for i in range(1, 4):
        result = await send_p_operation(dut, i)
        cocotb.log.info(f"P {i} -> {result} (expected 0)")
        if result != 0:
            raise TestFailure(f"Expected 0 (NE), got {result}")
    
    cocotb.log.info("All tests passed!")