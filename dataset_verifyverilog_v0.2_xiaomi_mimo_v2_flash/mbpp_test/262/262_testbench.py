import cocotb
from cocotb.triggers import Timer, RisingEdge
from cocotb.clock import Clock
import random

@cocotb.test()
async def test_array_splitter(dut):
    """Test the array_splitter module"""
    
    # Setup clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())
    
    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.data_in.value = 0
    dut.L.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)
    
    # Test Cases
    test_cases = [
        # (input_list, L)
        ([1, 1, 2, 3, 4, 4, 5, 1], 3),
        (['a', 'b', 'c', 'd'], 2),
        (['p', 'y', 't', 'h', 'o', 'n'], 4)
    ]
    
    # Convert string characters to integers for hardware simulation
    processed_cases = []
    for lst, L in test_cases:
        int_lst = [ord(c) if isinstance(c, str) else c for c in lst]
        # Pad to 16 elements with 0
        padded = int_lst + [0] * (16 - len(int_lst))
        processed_cases.append((padded, L))
        
    passed = 0
    total = len(processed_cases)
    
    for data, L in processed_cases:
        # Prepare inputs
        dut.L.value = L
        
        # Create the packed value for data_in
        # data_in is [15:0][7:0], so index 0 is bits 7:0
        packed_val = 0
        for i in range(16):
            packed_val |= (data[i] << (i * 8))
        dut.data_in.value = packed_val
        
        # Start
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for done (Latency is 16 cycles per spec)
        # We wait 16 rising edges
        for _ in range(16):
            await RisingEdge(dut.clk)
            
        if dut.done.value == 1:
            # Read outputs
            # part1 and part2 are also packed arrays
            p1_val = int(dut.part1.value)
            p2_val = int(dut.part2.value)
            
            # Unpack and verify
            # Expected part1: first L elements from data, rest 0
            # Expected part2: elements from index L to 15, rest 0
            
            errors = []
            
            # Check Part 1
            for i in range(16):
                # Extract byte from packed value
                out_byte = (p1_val >> (i * 8)) & 0xFF
                if i < L:
                    if out_byte != data[i]:
                        errors.append(f"Part1 idx {i}: exp {data[i]} got {out_byte}")
                else:
                    if out_byte != 0:
                        errors.append(f"Part1 idx {i}: exp 0 got {out_byte}")
                        
            # Check Part 2
            for i in range(16):
                out_byte = (p2_val >> (i * 8)) & 0xFF
                if i >= L:
                    # Expected value is at index i in original data
                    if out_byte != data[i]:
                        errors.append(f"Part2 idx {i}: exp {data[i]} got {out_byte}")
                else:
                    if out_byte != 0:
                        errors.append(f"Part2 idx {i}: exp 0 got {out_byte}")
                        
            if not errors:
                passed += 1
                dut._log.info(f"Test passed for L={L}")
            else:
                dut._log.error(f"Test failed for L={L}: {errors}")
        else:
            dut._log.error(f"Test failed for L={L}: Done signal not high")
            
    dut._log.info(f"Summary: {passed}/{total} tests passed")
    assert passed == total, "Some tests failed"
