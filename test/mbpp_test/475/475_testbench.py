import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_sort_dict(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Key mapping (4-bit IDs)
    CHEM = 1; PHYS = 2; MATH = 4; BIO = 8  # Example encoding

    # Test cases (mapped to IDs, vals)
    tests = [
        {"size": 3, "keys": [CHEM, PHYS, MATH], "vals": [87, 83, 81], "expected": [CHEM, PHYS, MATH]},
        {"size": 3, "keys": [MATH, PHYS, CHEM], "vals": [400, 300, 250], "expected": [MATH, PHYS, CHEM]},
        {"size": 3, "keys": [MATH, PHYS, CHEM], "vals": [900, 1000, 1250], "expected": [CHEM, PHYS, MATH]},
        {"size": 2, "keys": [BIO, CHEM], "vals": [150, 200], "expected": [CHEM, BIO]},
        {"size": 4, "keys": [MATH, PHYS, CHEM, BIO], "vals": [500, 700, 600, 300], "expected": [PHYS, CHEM, MATH, BIO]}
    ]

    passed = 0
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    for test in tests:
        # Apply inputs
        dut.start.value = 0
        dut.size.value = test["size"]
        for i in range(4):
            dut.keys_in[i].value = test["keys"][i] if i < test["size"] else 0
            dut.vals_in[i].value = test["vals"][i] if i < test["size"] else 0
        
        # Start sorting
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        # Verify results
        correct = True
        for i in range(test["size"]):
            if dut.sorted_keys[i].value != test["expected"][i]:
                correct = False
            if i > 0:
                if dut.sorted_vals[i].value > dut.sorted_vals[i-1].value:
                    correct = False
        
        if correct:
            passed += 1
            dut._log.info(f"PASS: Test {passed}")
        else:
            dut._log.error(f"FAIL: Got {[int(dut.sorted_keys[i].value) for i in range(4)]}, Expected {test["expected"]}")
        
        await RisingEdge(dut.clk)
    
    dut._log.info(f"{passed}/{len(tests)} tests passed")