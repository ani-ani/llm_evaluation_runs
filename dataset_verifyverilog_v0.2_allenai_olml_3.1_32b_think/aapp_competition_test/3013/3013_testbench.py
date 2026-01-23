import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer
import math

@cocotb.test()
async def test_archimedes_solver(dut):
    # Create clock (10ns period)
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.b_fixed.value = 0
    dut.tx_fixed.value = 0
    dut.ty_fixed.value = 0
    await Timer(50, units="ns")
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Helper function to convert float to Q16.16
    def to_q16_16(val):
        return int(val * 65536)
    
    # Helper function to convert Q16.16 to float
    def to_float(q):
        return q / 65536.0
    
    # Test cases
    test_cases = [
        {"b": 0.5, "tx": -5.301, "ty": 3.098, "expected_x": -1.26167861, "expected_y": 3.88425357},
        {"b": 0.5, "tx": 8.0, "ty": 8.0, "expected_x": 9.21068947, "expected_y": 2.56226688},
        {"b": 1.0, "tx": 8.0, "ty": 8.0, "expected_x": 6.22375968, "expected_y": -0.31921472},
        {"b": 0.5, "tx": -8.0, "ty": 8.0, "expected_x": -4.36385220, "expected_y": 9.46891588},
    ]
    
    passed = 0
    total = len(test_cases)
    
    for i, tc in enumerate(test_cases):
        print(f"
Running Test Case {i+1}: b={tc['b']}, target=({tc['tx']}, {tc['ty']})")
        
        # Set inputs
        dut.b_fixed.value = to_q16_16(tc['b'])
        dut.tx_fixed.value = to_q16_16(tc['tx'])
        dut.ty_fixed.value = to_q16_16(tc['ty'])
        await RisingEdge(dut.clk)
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done
        timeout = 0
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 50000:  # Safety timeout
                print("Timeout waiting for done!")
                break
        
        if dut.done.value == 1:
            result_x = to_float(int(dut.result_x.value))
            result_y = to_float(int(dut.result_y.value))
            
            print(f"Expected: ({tc['expected_x']:.8f}, {tc['expected_y']:.8f})")
            print(f"Got:      ({result_x:.8f}, {result_y:.8f})")
            
            # Check with 1e-5 tolerance
            err_x = abs(result_x - tc['expected_x'])
            err_y = abs(result_y - tc['expected_y'])
            
            if err_x < 1e-5 and err_y < 1e-5:
                print("PASS")
                passed += 1
            else:
                print(f"FAIL: Errors ({err_x:.6e}, {err_y:.6e})")
        else:
            print("FAIL: Module did not complete")
    
    print(f"
=== Summary: {passed}/{total} tests passed ===")
