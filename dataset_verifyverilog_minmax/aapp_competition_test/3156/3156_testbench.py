import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, Timer

@cocotb.test()
async def test_store_path(dut):
    clock = Clock(dut.clk, 10, units="ns")
    cocotb.start_soon(clock.start())

    # Item mappings (string to ID): chocolate=0, icecream=1, cookies=2, tomatoes=3, cucumber=4
    # Test cases: [scale original examples to 4 items/stores]
    test_cases = [
        # Original Sample 1 (adjusted)
        {"num_stores": 3, "stores": [0,1,2], "items": [0,1,2], "bought": [0,2,1], "exp": 0},
        # Original Sample 2 (adjusted)
        {"num_stores": 3, "stores": [0,1,2,2], "items": [0,1,2,0], "bought": [0,1,2], "exp": 1},
        # Edge case: multiple paths
        {"num_stores": 2, "stores": [0,1,1], "items": [0,0,1], "bought": [0,1], "exp": 2}
    ]

    passed = 0
    for tc in test_cases:
        await RisingEdge(dut.clk)
        dut.rst_n.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1

        # Load data (pad with 0 for unused)
        dut.num_stores.value = tc["num_stores"]
        for i in range(4):
            dut.store_ids[i].value = tc["stores"][i] if i < len(tc["stores"]) else 0
            dut.item_ids[i].value = tc["items"][i] if i < len(tc["items"]) else 0
        for i in range(4):
            dut.bought_list[i].value = tc["bought"][i] if i < len(tc["bought"]) else 0
        dut.num_bought.value = len(tc["bought"])

        # Start processing
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0

        # Wait for completion (m+2 cycles)
        for _ in range(len(tc["bought"]) + 2):
            await RisingEdge(dut.clk)

        # Check result
        if dut.done.value == 1 and dut.result.value == tc["exp"]:
            passed += 1
        else:
            dut._log.error(f"Test failed: Expected {tc['exp']} Got {dut.result.value}")

    dut._log.info(f"{passed}/{len(test_cases)} tests passed")