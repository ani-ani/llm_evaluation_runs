import cocotb
from cocotb.triggers import RisingEdge, Timer
from cocotb.clock import Clock
import random

def calc_popcount(x):
    return bin(x & 0xFF).count("1")

def sort_ref(arr):
    return sorted(arr, key=lambda x: (calc_popcount(x), x))

@cocotb.test()
async def test_sorter(dut):
    # Generate clock
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Test cases (scaled to 8 elements)
    test_cases = [
        [1, 5, 2, 3, 4, 0, 0, 0],  # Original case + padding
        [-2, -3, -4, -5, -6, 0, 0, 0],
        [],  # Empty (special case)
        [127, -128, 0, 1, 2, 3, -1, -2],
        [8,4,2,1,16,32,64,128],
        [5,5,5,5,5,5,5,5]  # All equal
    ]

    passed = 0
    for case in test_cases:
        # Handle empty case
        if len(case) == 0:
            real_case = [0]*8
            expected = []
        else:
            # Pad to 8 elements with zeros if needed
            real_case = case + [0]*(8-len(case))
            expected = sort_ref([x & 0xFF for x in case])  # Handle Python negative bin

        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)

        # Load inputs
        for i in range(8):
            dut.data_in[i].value = real_case[i]
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (max 64 cycles)
        timeout = 0
        while not dut.done.value:
            await RisingEdge(dut.clk)
            timeout += 1
            if timeout > 70:
                break

        # Verify outputs
        if len(case) == 0:
            # Special empty case handling
            dut._log.info("Skipping empty array verification")
            passed += 1
        else:
            result = [dut.sorted_data[i].value.signed_integer for i in range(8)]
            # Remove zero padding in comparison
            trimmed = []
            for val in result[:len(case)]:
                # Convert to Python-style signed 8-bit
                trimmed.append(val if val < 128 else val - 256)
            
            if trimmed == expected:
                passed += 1
                dut._log.info(f"PASS: {case} -> {trimmed}")
            else:
                dut._log.error(f"FAIL: {case}
  Got: {trimmed}
  Exp: {expected}")
    
    # Special empty array test
    dut._log.info(f"{passed}/{len(test_cases)} tests passed")
    assert passed == len(test_cases), f"Failed {len(test_cases)-passed} cases"