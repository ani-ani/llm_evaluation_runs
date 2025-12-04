import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
from cocotb.binary import BinaryValue
import itertools

@cocotb.test()
async def test_monotonic_counter(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    # Test case 1: 3x3 sample grid (expected: 49)
    grid1 = [
        1,2,5,0,
        7,6,4,0,
        9,8,3,0,
        0,0,0,0]
    # Test case 2: 4x3 example (expected:64)
    grid2 = [
        8,2,5,0,
        12,9,6,0,
        3,1,10,0,
        11,7,4,0]
    # Run tests
    passed = 0
    for (r,c,grid,expected) in [(3,3,grid1,49), (4,3,grid2,64)]:
        dut.r_in.value = r
        dut.c_in.value = c
        dut.grid.value = BinaryValue(''.join([f'{x:05b}' for x in grid]), n_bits=80)
        dut.start.value = 1
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        result = dut.count.value.integer
        if result == expected:
            passed +=1
            dut._log.info(f'Grid ({r}x{c}) PASS: {result}')
        else:
            dut._log.error(f'Grid ({r}x{c}) FAIL: got {result}, expected {expected}')
        await RisingEdge(dut.clk)
    dut._log.info(f'{passed}/2 tests passed')