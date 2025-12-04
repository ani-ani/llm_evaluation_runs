import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sticker_assembler(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test 1: Possible case
        {
            'msg': 'BUYSTICK', # 8 chars
            'stickers': [
                ('BUY ', 10),
                ('STIC', 10),
                ('TICK', 1),
                ('CK  ', 8)
            ],
            'expected_cost': 20,
            'expected_impossible': 0
        },
        # Test 2: Impossible case
        {
            'msg': 'ABBBA   ', # 8 chars (pad with spaces)
            'stickers': [
                ('AAAA', 10),
                ('BB  ', 3),
                ('    ', 0),
                ('    ', 0)
            ],
            'expected_cost': 0,
            'expected_impossible': 1
        }
    ]
    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    for case in test_cases:
        dut.start.value = 0
        # Load inputs
        msg_bytes = bytes(case['msg'], 'ascii')
        dut.message.value = int.from_bytes(msg_bytes, 'big')
        dut.num_stickers.value = len(case['stickers'])
        # Load stickers (up to 4)
        for i in range(4):
            if i < len(case['stickers']):
                word, price = case['stickers'][i]
                word_bytes = bytes(word, 'ascii')
                eval(f'dut.sticker_word_{i}.value = int.from_bytes(word_bytes, "big")')
                eval(f'dut.sticker_price_{i}.value = price')
            else:
                eval(f'dut.sticker_word_{i}.value = 0')
                eval(f'dut.sticker_price_{i}.value = 0')
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for completion (max 64 cycles)
        timeout = 70
        while not dut.done.value and timeout > 0:
            await RisingEdge(dut.clk)
            timeout -= 1
        if timeout == 0:
            dut._log.error("Test timed out")
            continue
        # Check results
        if dut.impossible.value == case['expected_impossible']:
            if dut.impossible.value or dut.min_cost.value == case['expected_cost']:
                passed += 1
            else:
                dut._log.error(f"Cost mismatch: got {dut.min_cost.value}, expected {case['expected_cost']}")
        else:
            dut._log.error(f"Impossible flag wrong: got {dut.impossible.value}, expected {case['expected_impossible']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
