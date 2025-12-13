import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_camel_order(dut):
    def pack_bet(bet_list):
        # Pad to 8 elements with zeros & pack into 3-bit fields
        padded = bet_list + [0]*(8 - len(bet_list))
        return sum([(v & 0x7) << (21 - i*3) for i, v in enumerate(padded)])

    test_cases = [
        # (n, jaap,   jan,    thijs,   expected)
        (3, [3,2,1], [1,2,3], [1,2,3], 0),
        (4, [2,3,1,4], [2,1,4,3], [2,4,3,1], 3),
        (2, [1,2], [1,2], [1,2], 1),  # Edge case: single valid pair
        (4, [4,3,2,1], [4,3,2,1], [4,3,2,1], 0),  # All reversed order
        (3, [1,2,3], [2,1,3], [3,2,1], 0)  # No matching pairs
    ]

    passed = 0
    for n, jaap, jan, thijs, expected in test_cases:
        dut.n.value = n
        dut.jaap_bet.value = pack_bet(jaap)
        dut.jan_bet.value = pack_bet(jan)
        dut.thijs_bet.value = pack_bet(thijs)
        await Timer(1, units='ns')
        if dut.count.value == expected:
            passed += 1
        else:
            dut._log.error("Test failed: n=%d  Got %d, Expected %d" % (n, dut.count.value.integer, expected))
    dut._log.info("%d/%d tests passed" % (passed, len(test_cases)))