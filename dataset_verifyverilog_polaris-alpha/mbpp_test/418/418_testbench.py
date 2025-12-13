import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_max_length(dut):
    test_cases = [
        {
            'lists': [[0x41,0,0,0], [0x41,0x42,0,0], [0x41,0x42,0x43,0]],
            'lengths': [1,2,3],
            'expected': [0x41,0x42,0x43,0]
        }
    ]
    passed = 0
    for case in test_cases:
        for i in range(4):
            dut.sublist_valid[i].value = i < len(case['lists']) # Only 3 sublists
            for j in range(4):
                getattr(dut, f"element_{i}_{j}").value = case['lists'][i][j] if j < case['lengths'][i] else 0
        await Timer(1, units='ns')
        […] # Full test verification logic
        dut._log.info(f"{passed}/{len(test_cases)} tests passed")