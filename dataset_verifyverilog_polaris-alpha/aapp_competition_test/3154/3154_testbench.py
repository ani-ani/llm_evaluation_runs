import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock

@cocotb.test()
async def test_toy_assignment(dut):
    # Create clock (100 MHz)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset sequence
    dut.rst_n.value = 0
    dut.start.value = 0
    await RisingEdge(dut.clk)
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Adapted test cases
    test_suites = [
        {   # Sample Input 1 (2 kids, 3 toys)
            "kids": 2,
            "toys": 3,
            "events": [
                (0, 1, 1), (0, 2, 2), 
                (1, 1, 3), (2, 1, 2), 
                (2, 2, 1), (3, 2, 3), (4, 2, 1)
            ],
            "expected": b"1 2
",  # Valid assignment exists
            "impossible": False
        },
        {   # Sample Input 2 (2 kids, 1 toy)
            "kids": 2,
            "toys": 1,
            "events": [
                (0, 1, 1), (10, 1, 0), (10, 2, 1)
            ],
            "expected": b"impossible
",
            "impossible": True
        },
        {   # Additional test case (1 kid, 3 toys)
            "kids": 1,
            "toys": 3,
            "events": [
                (0, 1, 1), (1, 1, 2), (2, 1, 3)
            ],
            "expected": b"2
",
            "impossible": False
        }
    ]
    
    passed = 0
    for suite in test_suites:
        # Load test data (simulation only - real HW would use ROM)
        dut.in_event_count.value = len(suite["events"])
        # (In real HW would load events via interface with kid/toy data)
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done signal (max 300 cycles)
        for _ in range(300):
            await RisingEdge(dut.clk)
            if dut.done.value == 1:
                break
        
        # Verify results
        if suite["impossible"]:
            if dut.impossible_flag.value != 1:
                dut._log.error(f"Expected impossible but got valid assignment for {suite}")
            else:
                passed += 1
        else:
            if dut.impossible_flag.value == 1:
                dut._log.error(f"Expected solution but got impossible for {suite}")
            else:
                actual = bytearray()
                for i in range(suite["kids"]):
                    toy = dut.assignments.value >> (2*i) & 0x3
                    actual.extend(f"{toy} ".encode())
                actual = actual[:-1] + b'
'  # Replace last space with newline
                
                if actual != suite["expected"]:
                    dut._log.error(f"Mismatch: Exp {suite['expected']!r} got {actual!r} ")
                else:
                    passed += 1
        
        # Reset module between tests
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
    
    # Summary
    total = len(test_suites)
    dut._log.info(f"Test results: {passed}/{total} passed")
    assert passed == total, f"Failed {total-passed} tests"