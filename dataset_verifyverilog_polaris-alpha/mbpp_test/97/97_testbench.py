import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_frequency(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Helper function to set list input
    def set_list(test_list):
        # Flatten to 4x4 (pad with 0 if needed)
        flat = [item for sublist in test_list for item in sublist] + [0]*(16-len([item for sublist in test_list for item in sublist]))
        for i in range(4):
            for j in range(4):
                dut.list1[i][j].value = flat[i*4 + j]
    
    # Test cases (simplified to fit 4x4)
    test_cases = [
        ([[1,2,2,0], [4,5,2,0], [0,0,0,0],[0,0,0,0]], {1:1, 2:3, 4:1, 5:1}),
        ([[1,2,3,4], [5,6,7,8], [9,10,11,12],[0,0,0,0]], {1:1, 2:1, 3:1, 4:1, 5:1, 6:1, 7:1, 8:1, 9:1, 10:1, 11:1, 12:1}),
        ([[20,30,40,17], [18,16,14,13], [10,20,30,40],[0,0,0,0]], {20:2,30:2,40:2,17:1,18:1,16:1,14:1,13:1,10:1})
    ]
    
    passed = 0
    total = len(test_cases)
    
    for idx, (input_list, expected) in enumerate(test_cases):
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load input
        set_list(input_list)
        
        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for processing (16 cycles)
        for _ in range(17):
            await RisingEdge(dut.clk)
        
        # Check results
        if not dut.done.value:
            dut._log.error(f"Test {idx}: Done not asserted after processing")
            continue
        
        case_passed = True
        for num, count in expected.items():
            dut.query_num.value = num
            await Timer(1, units='ns')  # Allow output to settle
            if dut.frequency.value != count:
                dut._log.error(f"Test {idx}: Num {num} got {dut.frequency.value}, expected {count}")
                case_passed = False
        
        if case_passed:
            passed += 1
            dut._log.info(f"Test {idx} PASSED")
        else:
            dut._log.error(f"Test {idx} FAILED")
    
    dut._log.info(f"
SUMMARY: {passed}/{total} tests passed")
    assert passed == total