import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge
from cocotb.result import TestFailure

@cocotb.test()
async def test_doggo_standardization(dut):
    # Create clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())

    # Reset
    dut.rst_n.value = 0
    dut.start.value = 0
    dut.char_in.value = 0
    dut.char_valid.value = 0
    await Timer(20, units='ns')
    await RisingEdge(dut.clk)
    dut.rst_n.value = 1
    await RisingEdge(dut.clk)

    # Helper to send a string
    async def send_string(s):
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        for char in s:
            val = ord(char) - ord('a')
            dut.char_in.value = val
            dut.char_valid.value = 1
            await RisingEdge(dut.clk)
        
        dut.char_valid.value = 0
        
        # Wait for done
        while not dut.done.value:
            await RisingEdge(dut.clk)
        
        return dut.result.value

    # Test Case 1: Yes (aabddc) - has duplicates
    # 'a':2, 'b':1, 'd':2, 'c':1 -> Yes
    res = await send_string("aabddc")
    if res != 1:
        raise TestFailure(f"Test 1 failed: expected 1, got {res}")
    await RisingEdge(dut.clk)

    # Test Case 2: No (abc) - all unique
    # 'a':1, 'b':1, 'c':1 -> No
    res = await send_string("abc")
    if res != 0:
        raise TestFailure(f"Test 2 failed: expected 0, got {res}")
    await RisingEdge(dut.clk)

    # Test Case 3: Yes (jjj) - all same
    # 'j':3 -> Yes
    res = await send_string("jjj")
    if res != 1:
        raise TestFailure(f"Test 3 failed: expected 1, got {res}")
    await RisingEdge(dut.clk)

    # Test Case 4: Yes (single char)
    res = await send_string("x")
    if res != 1:
        raise TestFailure(f"Test 4 failed: expected 1, got {res}")
    await RisingEdge(dut.clk)

    # Test Case 5: Yes (two different chars, count 1 each -> No actually, wait)
    # "az" -> a:1, z:1 -> No
    res = await send_string("az")
    if res != 0:
        raise TestFailure(f"Test 5 failed: expected 0, got {res}")
    await RisingEdge(dut.clk)

    # Test Case 6: Yes (two same chars)
    res = await send_string("aa")
    if res != 1:
        raise TestFailure(f"Test 6 failed: expected 1, got {res}")

    print("All tests passed!")