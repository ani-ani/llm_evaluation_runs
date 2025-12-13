import cocotb
from cocotb.triggers import RisingEdge, ClockCycles
from cocotb.clock import Clock

animal_map = {"monkey": 0, "lion": 1, "penguin": 2, "elephant": 3}

@cocotb.test()
async def test_sanctuary(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Test cases - scaled down to 3 enclosures
    test_cases = [
        ( # Test 1 - Sample POSSIBLE
            [0, 1, 2],  # correct_animal: monkey(0), lion(1), penguin(2)
            [2, 3, 1],  # current_counts: 2, 3, 1 (total=6)
            [1,2, 0,2,1, 0,0,0], # animals: lion(1), penguin(2) | monkey(0),penguin(2),lion(1) | monkey(...)
            "POSSIBLE" # expected
        ),
        ( # Test 2 - Sample IMPOSSIBLE
            [3, 0],  # giraffe(3), elephant(0)
            [3, 1],  # 3 elephant in giraffe, 1 giraffe in elephant
            [0,0,0, 3, 3,0,0,0],
            "IMPOSSIBLE"
        ),
        ( # Test 3 - FALSE ALARM
            [1, 2], # lion, penguin
            [1, 1], # both correct
            [1,2, 0,0,0,0,0,0],
            "FALSE_ALARM"
        )
    ]

    passed = 0
    dut.start.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 2)
    dut.rst_n.value = 1

    for i, (correct, counts, animals, expected_str) in enumerate(test_cases):
        # Configure inputs
        for enc in range(4):
            dut.correct_animal[enc].value = correct[enc] if enc < len(correct) else 0
            dut.current_count[enc].value = counts[enc] if enc < len(counts) else 0
        for j in range(8):
            animal_val = animals[j] if j < len(animals) else 0
            dut.current_animals[j].value = animal_val

        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Check result
        expected = {"FALSE_ALARM":0, "POSSIBLE":1, "IMPOSSIBLE":2}[expected_str]
        if dut.result.value == expected:
            passed += 1
            dut._log.info(f"Test {i} passed")
        else:
            dut._log.error(f"Test {i} failed. Got {dut.result.value}, expected {expected_str}")
        await ClockCycles(dut.clk, 2)
    
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases)
