import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer

@cocotb.test()
async def test_plant_flowers(dut):
    """Test plant flower counting for small N"""
    
    # Initialize all inputs
    dut.day.value = 0
    dut.new_L.value = 0
    dut.new_R.value = 0
    for i in range(8):
        dut.prev_L[i].value = 0
        dut.prev_R[i].value = 0
        dut.prev_H[i].value = 0
    
    await Timer(10, units='ns')
    
    # Test case 1: Day 1 - no previous plants
    dut.day.value = 1
    dut.new_L.value = 1
    dut.new_R.value = 4
    await Timer(10, units='ns')
    assert dut.flowers.value == 0, f"Day 1: Expected 0 flowers, got {int(dut.flowers.value)}"
    print("Test 1 passed: Day 1, no previous plants -> 0 flowers")
    
    # Test case 2: Day 2 - one previous plant
    # Plant 1: L=1, R=4, H=1
    # Plant 2: L=3, R=7, H=2
    # Left stem of plant 2 at x=3: intersects plant 1? 1<3<4 yes. Right stem at 7: 1<7<4 no. So 1 flower.
    dut.day.value = 2
    dut.new_L.value = 3
    dut.new_R.value = 7
    dut.prev_L[0].value = 1  # Plant 1
    dut.prev_R[0].value = 4
    dut.prev_H[0].value = 1
    for i in range(1, 8):
        dut.prev_L[i].value = 0
        dut.prev_R[i].value = 0
        dut.prev_H[i].value = 0
    await Timer(10, units='ns')
    assert dut.flowers.value == 1, f"Day 2: Expected 1 flower, got {int(dut.flowers.value)}"
    print("Test 2 passed: Day 2 -> 1 flower")
    
    # Test case 3: Day 3 - two previous plants
    # Plant 1: L=1, R=4, H=1
    # Plant 2: L=3, R=7, H=2  
    # Plant 3: L=1, R=6, H=3
    # Check vs Plant 1: Left 1 vs 1-4 (touch at L, no flower), Right 6 vs 1-4 (6>4, no). So 0 from Plant 1.
    # Check vs Plant 2: Left 1 vs 3-7 (1<3, no), Right 6 vs 3-7 (3<6<7 yes). So 1 from Plant 2.
    # Total: 1 flower.
    dut.day.value = 3
    dut.new_L.value = 1
    dut.new_R.value = 6
    dut.prev_L[0].value = 1
    dut.prev_R[0].value = 4
    dut.prev_H[0].value = 1
    dut.prev_L[1].value = 3
    dut.prev_R[1].value = 7
    dut.prev_H[1].value = 2
    for i in range(2, 8):
        dut.prev_L[i].value = 0
        dut.prev_R[i].value = 0
        dut.prev_H[i].value = 0
    await Timer(10, units='ns')
    assert dut.flowers.value == 1, f"Day 3: Expected 1 flower, got {int(dut.flowers.value)}"
    print("Test 3 passed: Day 3 -> 1 flower")
    
    # Test case 4: Day 4 - three previous plants
    # Plant 1: L=1, R=4, H=1
    # Plant 2: L=3, R=7, H=2
    # Plant 3: L=1, R=6, H=3
    # Plant 4: L=2, R=6, H=4
    # Check vs Plant 1: Left 2 in (1,4) yes, Right 6 in (1,4) no. -> 1 flower from Plant 1.
    # Check vs Plant 2: Left 2 in (3,7) no, Right 6 in (3,7) yes. -> 1 flower from Plant 2.
    # Check vs Plant 3: Left 2 in (1,6) yes, Right 6 in (1,6) no (touch). -> 1 flower from Plant 3? But already counted? No, per plant max 1.
    # Wait, let's re-verify carefully.
    # Plant 1: H=1. Left 2: 1<2<4 yes. Right 6: 1<6<4 no. So yes to left.
    # Plant 2: H=2. Left 2: 2<2<7 no (2 is not >2). Right 6: 2<6<7 yes. So yes to right.
    # Plant 3: H=3. Left 2: 3<2<6 no. Right 6: 3<6<6 no (6 is not <6). So no to Plant 3.
    # Total: 2 flowers.
    dut.day.value = 4
    dut.new_L.value = 2
    dut.new_R.value = 6
    dut.prev_L[0].value = 1
    dut.prev_R[0].value = 4
    dut.prev_H[0].value = 1
    dut.prev_L[1].value = 3
    dut.prev_R[1].value = 7
    dut.prev_H[1].value = 2
    dut.prev_L[2].value = 1
    dut.prev_R[2].value = 6
    dut.prev_H[2].value = 3
    for i in range(3, 8):
        dut.prev_L[i].value = 0
        dut.prev_R[i].value = 0
        dut.prev_H[i].value = 0
    await Timer(10, units='ns')
    assert dut.flowers.value == 2, f"Day 4: Expected 2 flowers, got {int(dut.flowers.value)}"
    print("Test 4 passed: Day 4 -> 2 flowers")
    
    # Test case 5: Multiple intersections on same side
    dut.day.value = 3
    dut.new_L.value = 5
    dut.new_R.value = 10
    dut.prev_L[0].value = 4  # Plant 1: L=4, R=6, H=1
    dut.prev_R[0].value = 6
    dut.prev_H[0].value = 1
    dut.prev_L[1].value = 5  # Plant 2: L=5, R=8, H=2
    dut.prev_R[1].value = 8
    dut.prev_H[1].value = 2
    for i in range(2, 8):
        dut.prev_L[i].value = 0
        dut.prev_R[i].value = 0
        dut.prev_H[i].value = 0
    await Timer(10, units='ns')
    # Left stem x=5: Plant 1 (H=1, 4<5<6 yes) -> flower. Plant 2 (H=2, 5<5<8 no).
    # Right stem x=10: Plant 1 (1<10<6 no), Plant 2 (2<10<8 no).
    # So only 1 flower.
    assert dut.flowers.value == 1, f"Test 5: Expected 1 flower, got {int(dut.flowers.value)}"
    print("Test 5 passed: Multiple plants -> 1 flower")
    
    print(f"
Summary: All {5} tests passed")
