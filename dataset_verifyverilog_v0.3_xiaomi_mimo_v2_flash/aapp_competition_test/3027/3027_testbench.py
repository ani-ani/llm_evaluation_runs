import cocotb
from cocotb.triggers import Timer, RisingEdge, FallingEdge
from cocotb.clock import Clock
from cocotb.result import TestFailure

def is_value_defined(value):
    try:
        int(value)
        return True
    except ValueError:
        return False

def has_signal(dut, name):
    try:
        getattr(dut, name)
        return True
    except AttributeError:
        return False

def clamp_to_width(value, bits):
    max_val = (1 << bits) - 1
    return min(max_val, max(0, value))

GRID_SIZE = 8
MAX_CYCLES = 10000

@cocotb.test(timeout_time=10000, timeout_unit="ms")
async def test_bureaucrat_stamp(dut):
    cocotb.start_soon(Clock(dut.clk, 10, units='ns').start())
    
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    test_cases = [
        ([0b00100100, 0b01111110, 0b01111110, 0b00100100, 0, 0, 0, 0], 8, "Sample 1"),
        ([0, 0, 0, 0, 0b00010000, 0, 0, 0], 1, "Sample 2"),
        ([0b00111110, 0b01111100, 0, 0, 0, 0, 0, 0], 5, "Sample 3"),
        ([0b00010100, 0b00101010, 0, 0, 0, 0, 0, 0], 3, "Additional"),
    ]
    
    passed = 0
    failed = 0
    
    for i, (grid, expected, desc) in enumerate(test_cases):
        cocotb.log.info(f"Test {i+1}: {desc}")
        try:
            for j in range(GRID_SIZE):
                if has_signal(dut, f'grid_in_{j}'):
                    getattr(dut, f'grid_in_{j}').value = grid[j]
                elif has_signal(dut, 'grid_in'):
                    dut.grid_in[j].value = grid[j]
                else:
                    raise TestFailure("Grid signal not found")
            
            dut.start.value = 1
            await RisingEdge(dut.clk)
            dut.start.value = 0
            
            if has_signal(dut, 'done'):
                cycles = 0
                while not is_value_defined(dut.done.value) or int(dut.done.value) == 0:
                    await RisingEdge(dut.clk)
                    cycles += 1
                    if cycles > MAX_CYCLES:
                        raise TestFailure(f"Timeout")
            else:
                await Timer(100, units='ns')
            
            if not has_signal(dut, 'min_nubs'):
                raise TestFailure("Output not found")
            
            result = int(dut.min_nubs.value)
            if result != expected:
                raise TestFailure(f"Expected {expected}, got {result}")
            
            cocotb.log.info(f"  PASS: {result}")
            passed += 1
        except TestFailure as e:
            cocotb.log.error(f"  FAIL: {e}")
            failed += 1
    
    cocotb.log.info(f"Results: {passed}/{passed+failed} passed")
    if failed > 0:
        raise TestFailure(f"{failed} failed")