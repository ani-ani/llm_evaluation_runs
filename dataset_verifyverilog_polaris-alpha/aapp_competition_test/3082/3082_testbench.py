import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def test_buffet(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Test cases (scaled to 8-bit)
    test_cases = [
        (
            [0, 1],           # dish types: D then C
            [0x40, 0],         # w_i [4.0, 0] (continuous no weight)
            [10, 6],           # t_i
            [1, 1],            # dt_i
            0xF0,              # target_w (15.0)
            0xA200,            # expected (40.5 in Q8.8: 40<<8 | 0.5*256)
            False              # impossible?
        ),
        (
            [0, 1, 1],        # D, C, C
            [0x40, 0, 0],     # w_i
            [10, 6, 9],      # t_i
            [1, 1, 3],       # dt_i
            0xF0,            # 15.0
            0xC400,          # 49.0 (0xC400 = 49<<8)
            False
        ),
        (
            [0, 0],           # two discrete dishes
            [0x40, 0x60],     # w_i=4 and 6 (integers)
            [5, 3],           # t_i
            [1, 2],           // dt_i
            0x130,            // target=19 (scaled to 4.75 in Q4.4 but test shows impossible)
            0,                // irrelevant
            True              // impossible
        )
    ]
    passed = 0
    dut.rst_n.value = 0
    await Timer(15, units="ns")
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for case in test_cases:
        (types, w_i, t_i, dt_i, target, expected, impossible) = case
        # Load dish data
        for i in range(4):
            dut.dish_type[i].value = types[i] if i < len(types) else 0
            dut.w_i[i].value = w_i[i] if i < len(w_i) else 0
            dut.t_i[i].value = t_i[i] if i < len(t_i) else 0
            dut.dt_i[i].value = dt_i[i] if i < len(dt_i) else 0
        dut.target_w.value = target
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (max 20 cycles)
        for _ in range(25):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        assert dut.done.value == 1, "Timeout waiting for done"
        if dut.impossible.value == impossible:
            if not impossible:
                # Allow 1% error margin (256 in Q8.8 = 1.0)
                expected_val = expected & 0xFFFF
                actual = dut.max_taste.value & 0xFFFF
                error = abs(actual - expected_val)/256.0
                if error <= 1.01:
                    passed +=1
                else:
                    dut._log.error(f"Error {error} too large! Expected {expected_val} got {actual}")
            else:
                passed +=1
        else:
            dut._log.error(f"Impossible flag wrong. Expected {impossible} got {dut.impossible.value}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")