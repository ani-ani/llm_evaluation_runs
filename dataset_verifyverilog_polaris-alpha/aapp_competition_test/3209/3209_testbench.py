import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
from fixedpoint import FixedPoint  # Requires cocotb's FixedPoint

@cocotb.test()
async def test_train_path(dut):
    clock = Clock(dut.clk, 10, units="ns")  # 100 MHz clock
    cocotb.start_soon(clock.start())
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test case 1: Hamburg(0)→Bremen(1) scaled to Q16.16
    test1 = [
        # [src, dst, depart, time, prob, delay] for 3 trains
        (0<<28) | (1<<24) | (15<<18) | (68<<9) | (10<<2) | 5,  # Train 0
        (0<<28) | (1<<24) | (46<<18) | (55<<9) | (50<<2) | 60, # Train 1
        (1<<28) | (2<<24) | (14<<18) | (226<<9) | (10<<2) | 120 # Irrelevant train
    ]
    for i in range(16):
        dut.train_data[i].value = test1[i] if i<3 else 0
    dut.num_stations.value = 3
    dut.num_trains.value = 3
    dut.origin_idx.value = 0
    dut.dest_idx.value = 1
    # Trigger computation
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    # Wait 16 cycles for computation
    for _ in range(20):
        await RisingEdge(dut.clk)
    # Expected: 68.3 min → Q16.16 = 68.3 * 65536 ≈ 4,478,566
    expected = FixedPoint(68.3, 16, 16, signed=False)
    assert dut.done.value == 1, "Test1: Computation not done"
    assert dut.impossible.value == 0, "Test1: Should be possible"
    result_fp = FixedPoint(dut.min_time.value.integer, 16, 16, signed=False)
    assert abs(result_fp - expected) < FixedPoint(0.1, 16, 16), f"Test1: Expected ~68.3 got {result_fp}"
    
    # Test case 2: Impossible route
    test2 = [
        (0<<28) | (1<<24) | (10<<18) | (22<<9) | (5<<2) | 10,
    ] + [0]*15
    for i in range(16):
        dut.train_data[i].value = test2[i] if i==0 else 0
    dut.num_stations.value = 2
    dut.num_trains.value = 1
    dut.origin_idx.value = 0
    dut.dest_idx.value = 1  # Different from train's dest
    dut.start.value = 1
    await RisingEdge(dut.clk)
    dut.start.value = 0
    for _ in range(20):
        await RisingEdge(dut.clk)
    assert dut.impossible.value == 1, "Test2: Should be impossible"
    
    # Test summary
    dut._log.info("2/2 tests passed")