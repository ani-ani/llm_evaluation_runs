import cocotb
from cocotb.triggers import Timer

@cocotb.test()
async def test_element_checker(dut):
    test_cases = [
        # Test 1: 'green','orange','black','white' != 'blue'
        (['g','o','b','w'], 'b', False),
        # Test 2: [1,2,3,4] != 7
        ([1,2,3,4], 7, False),
        # Test 3: All 'green' == 'green'
        (['g','g','g','g'], 'g', True)
    ]

    passed = 0
    for items, elem, expected in test_cases:
        dut.elem.value = ord(elem) if isinstance(elem, str) else elem
        for i in range(4):
            val = ord(items[i]) if isinstance(items[i], str) else items[i]
            getattr(dut, f"item{i}").value = val
        await Timer(1, units='ns')
        
        actual = dut.all_match.value
        if actual == expected:
            passed += 1
            dut._log.info(f"PASS: {'/'.join(map(str,items))} vs {elem} => {actual}")
        else:
            dut._log.error(f"FAIL: {'/'.join(map(str,items))} vs {elem} => {actual}, expected {expected}")
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")