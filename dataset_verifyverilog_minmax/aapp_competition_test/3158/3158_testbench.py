import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import math

@cocotb.test()
async def gesture_test(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    # Adapted test cases (images truncated to 8x16)
    test_cases = [
        ( # Test 1: Pan (scaled original sample 1)
            "........ ........" * 8 + "XXXX.... ........" * 3 + "........ ........" * 5,
            "........ ........" * 8 + "........ ...XXXX.." * 3 + "........ ........" * 5,
            1, 0, 0  # 1 touch, pan (dir unused)
        ),
        ( # Test 2: Zoom out (scaled sample 2)
            "........ ........" * 4 + "..XXX... ......." * 2 + "...XX... ........" * 2 + "........ ........" * 8,
            "........ ..XX...." * 1 + "........ .XXXX..." * 2 + "........ ..XX...." * 2 + "........ ........" * 11,
            3, 1, 1  # 3 touches, zoom out
        ),
        ( # Test 3: Rotate CCW (scaled sample 3)
            "........ ........" * 2 + "..XX.... ........" * 2 + "........ ........" + "XXX. ...XXX" * 2 + "........ ........" * 7,
            "........ .....XXX" * 2 + "........ ....XXX." * 2 + "........ ........XX" + "XX...... ........" * 3 + "........ ........" * 5,
            4, 2, 1  # 4 touches, rotate CCW
        )
    ]
    passed = 0
    dut.rst_n.value = 0
    await Timer(20, units="ns")
    dut.rst_n.value = 1
    for idx, (init_img, final_img, exp_cnt, exp_gest, exp_dir) in enumerate(test_cases):
        dut.init_image.value = int(init_img.replace('.','0').replace('X','1'), 2)
        dut.final_image.value = int(final_img.replace('.','0').replace('X','1'), 2)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for processing (256 cycles)
        for _ in range(260):
            await RisingEdge(dut.clk)
            if dut.done.value:
                break
        if dut.touch_count.value != exp_cnt:
            dut._log.error(f"Test {idx} failed: Count {dut.touch_count.value} != {exp_cnt}")
        elif dut.gesture_type.value != exp_gest:
            dut._log.error(f"Test {idx} failed: Gesture {dut.gesture_type.value} != {exp_gest}")
        elif exp_gest != 0 and dut.direction.value != exp_dir:
            dut._log.error(f"Test {idx} failed: Direction {dut.direction.value} != {exp_dir}")
        else:
            passed +=1
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
