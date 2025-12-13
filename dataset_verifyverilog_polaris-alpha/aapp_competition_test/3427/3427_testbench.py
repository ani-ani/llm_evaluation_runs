import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge, FallingEdge, Timer

@cocotb.test()
async def test_max_secure_rooms(dut):
    # Setup clock
    clock = Clock(dut.clk, 10, units='ns')
    cocotb.start_soon(clock.start())
    
    # Sample test cases (scaled and adapted)
    test_cases = [
        # Test 1: Sample Input 1
        {
            'num_rooms': 2,
            'num_doors': 3,
            'door_data': [
                (0xF << 4) | 0x0,  # -1,0
                (0xF << 4) | 0x1,  # -1,1
                (0x0 << 4) | 0x1,  # 0,1
            ],
            'expected': 0
        },
        # Test 2: Sample Input 2
        {
            'num_rooms': 6,
            'num_doors': 8,
            'door_data': [
                (0xF << 4) | 0x0,  # -1,0
                (0xF << 4) | 0x1,  # -1,1
                (0x0 << 4) | 0x1,  # 0,1
                (0x1 << 4) | 0x2,  # 1,2
                (0x2 << 4) | 0x3,  # 2,3
                (0x3 << 4) | 0x4,  # 3,4
                (0x2 << 4) | 0x4,  # 2,4
                (0x1 << 4) | 0x5,  # 1,5
            ],
            'expected': 3
        },
    ]
    
    passed = 0
    for tc in test_cases:
        # Reset
        dut.rst_n.value = 0
        dut.start.value = 0
        await RisingEdge(dut.clk)
        dut.rst_n.value = 1
        await RisingEdge(dut.clk)
        
        # Load inputs
        dut.num_rooms.value = tc['num_rooms']
        dut.num_doors.value = tc['num_doors']
        for i in range(16):
            if i < len(tc['door_data']):
                dut.door_data[i].value = tc['door_data'][i]
            else:
                dut.door_data[i].value = 0
        
        # Start computation
        dut.start.value = 1
        await RisingEdge(dut.clk)
        dut.start.value = 0
        
        # Wait for completion
        while dut.done.value == 0:
            await RisingEdge(dut.clk)
        
        # Check result
        if dut.result.value == tc['expected']:
            passed += 1
        else:
            dut._log.error(f'Test failed: Expected {tc['expected']}, got {dut.result.value}')
        await Timer(10, units='ns')
    
    dut._log.info(f'Tests passed: {passed}/{len(test_cases)}')