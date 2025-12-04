import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_bar_code_solver(dut):
    test_cases = [
        # TC1: n=2
        {
            "n": 2,
            "v_spec": [0x1000, 0x0000, 0,0,0,0],  # [1,0] for 2 rows
            "h_spec": [0x0000, 0x3000, 0,0,0,0],  # [0,3] cols
            "v_expect": 0b100_000 << 21,  # "100
", "000
"
            "h_expect": 0b01_01_01 << 21    # 3x"01
"
        },
        # TC2: n=3
        {
            "n": 3,
            "v_spec": [0x0000, 0x1100, 0x1000, 0,0,0],
            "h_spec": [0x1100, 0x1000, 0x1000, 0,0,0],
            "v_expect": 0b0000_1001_0010 << 28,
            "h_expect": 0b101_010_000_100 << 24 
        }
    ]

    passed = 0
    for tc in test_cases:
        dut.n.value = tc["n"]
        # Flatten specs (6 elements × 16 bits each)
        dut.v_spec_flat.value = (tc["v_spec"][5] << 80) | (tc["v_spec"][4] << 64) | 
                              (tc["v_spec"][3] << 48) | (tc["v_spec"][2] << 32) | 
                              (tc["v_spec"][1] << 16) | tc["v_spec"][0]
        dut.h_spec_flat.value = (tc["h_spec"][5] << 80) | (tc["h_spec"][4] << 64) | 
                              (tc["h_spec"][3] << 48) | (tc["h_spec"][2] << 32) | 
                              (tc["h_spec"][1] << 16) | tc["h_spec"][0]
        await Timer(10, units='ns')
        if (dut.vertical_bars.value == tc["v_expect"] and 
            dut.horizontal_bars.value == tc["h_expect"]):
            passed += 1
        else:
            dut._log.error(f"Test failed for n={tc['n']} Expected v={bin(tc['v_expect'])} h={bin(tc['h_expect'])}
Got v={bin(dut.vertical_bars.value)} h={bin(dut.horizontal_bars.value)}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
