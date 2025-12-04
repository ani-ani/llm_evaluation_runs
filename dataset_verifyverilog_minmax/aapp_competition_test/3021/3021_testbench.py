import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_lex_order(dut):
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    test_cases = [
        # Test case 1: Valid unique order (Sample 1 scaled)
        {
            'L': 3,  # 'd' (a=0, b=1, c=2, d=3)
            'N': 4,   # 4 words
            'words': [
                0b010000000001000000,  # 'cab' - c(2)=0b010, a(0)=0b000, b(1)=0b001
                0b010011000000000000,  # 'cda' - d(3)=0b011
                0b010010010000000000,  # 'ccc'
                0b001000011010000000   # 'badca'
            ],
            'exp_status': 0,
            'exp_order': 0b000011010001  # a(0), d(3), c(2), b(1)
        },
        # Test case 2: IMPOSSIBLE (Sample 2 scaled)
        {
            'L': 2,  # 'c' (a,b,c)
            'N': 4,
            'words': [
                0b000001010000000000,  # abc (a,b,c)
                0b001010000000000000,  # bca
                0b010000001000000000,  # cab
                0b000010000000000000   # aca
            ],
            'exp_status': 1,
            'exp_order': 0
        },
        # Test case 3: AMBIGUOUS (Sample 3 scaled)
        {
            'L': 5,  # 'f' (a,b,c,d,e,f)
            'N': 2,
            'words': [
                0b011100000000000000,  # dea (d,e,a)
                0b010101001000000000   # cfb (c,f,b)
            ],
            'exp_status': 2,
            'exp_order': 0
        }
    ]
    passed = 0
    dut.rst_n.value = 0
    await Timer(20, units='ns')
    dut.rst_n.value = 1
    for test in test_cases:
        dut.start.value = 0
        dut.L.value = test['L']
        dut.N.value = test['N']
        # Pack words into 192-bit vector
        packed_words = 0
        for i, word in enumerate(test['words']):
            packed_words |= word << (24 * (7 - i))  # word0 at MSB
        dut.words.value = packed_words
        await RisingEdge(dut.clk)
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        # Wait for done signal (max 11 cycles for L=8)
        for _ in range(15):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        if dut.status.value == test['exp_status']:
            if (dut.status.value == 0 and dut.order.value == test['exp_order']) or (dut.status.value != 0):
                passed += 1
                dut._log.info(f"Test passed: status={dut.status.value}, order={bin(dut.order.value)}")
            else:
                dut._log.error(f"Order mismatch: {bin(dut.order.value)} != expected {bin(test['exp_order'])}")
        else:
            dut._log.error(f"Status mismatch: {dut.status.value} != expected {test['exp_status']}")
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)