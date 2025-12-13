import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

# Q8.8 format conversion
def to_fixed(x):
    return int(x * (1 << 8))

@cocotb.test()
async def test_cloud_cover(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(15, units='ns')
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    test_cases = [
        # Test1: Different counts (g1 vs j2)
        {'g_tcount':1, 'g_tri1':(0,0,4,0,0,4), 'g_tri2':0,
         'j_tcount':2, 'j_tri1':(0,0,2,0,0,2), 'j_tri2':(0,2,2,0,2,2), 'expected':0},
        # Test2: Same count, same area
        {'g_tcount':1, 'g_tri1':(0,0,4,0,0,4), 'g_tri2':0,
         'j_tcount':1, 'j_tri1':(0,0,4,0,0,4), 'j_tri2':0, 'expected':1},
        # Test3: Same count, different area
        {'g_tcount':1, 'g_tri1':(0,0,4,0,0,4), 'g_tri2':0,
         'j_tcount':1, 'j_tri1':(0,0,2,0,0,2), 'j_tri2':0, 'expected':0}
    ]

    passed = 0
    for test in test_cases:
        # Encode triangle coordinates to Q8.8
        def pack_triangle(t):
            return (to_fixed(t[0])<<80 | to_fixed(t[1])<<64 | to_fixed(t[2])<<48 |
                    to_fixed(t[3])<<32 | to_fixed(t[4])<<16 | to_fixed(t[5]))

        dut.g_tcount.value = test['g_tcount']
        dut.g_tri1.value = pack_triangle(test['g_tri1']) if test['g_tcount'] >0 else 0
        dut.g_tri2.value = pack_triangle(test['g_tri2']) if test['g_tcount'] >1 else 0
        dut.j_tcount.value = test['j_tcount']
        dut.j_tri1.value = pack_triangle(test['j_tri1']) if test['j_tcount'] >0 else 0
        dut.j_tri2.value = pack_triangle(test['j_tri2']) if test['j_tcount'] >1 else 0
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for computation (5 cycles)
        for _ in range(5):
            await RisingEdge(dut.clk)
        assert dut.done.value == 1, "Done signal not asserted"
        if dut.result.value == test['expected']:
            passed +=1
        else:
            dut._log.error(f"Test failed: Expected {test['expected']}, got {dut.result.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
