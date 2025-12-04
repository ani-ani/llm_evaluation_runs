module max_fill_grid(
    input [15:0] grid,
    input [3:0] capacity,
    output reg [4:0] total_trips
);
    
    // Extract rows
    wire [3:0] row0 = grid[3:0];
    wire [3:0] row1 = grid[7:4];
    wire [3:0] row2 = grid[11:8];
    wire [3:0] row3 = grid[15:12];
    
    // Count ones in each row
    wire [2:0] count0 = row0[0] + row0[1] + row0[2] + row0[3];
    wire [2:0] count1 = row1[0] + row1[1] + row1[2] + row1[3];
    wire [2:0] count2 = row2[0] + row2[1] + row2[2] + row2[3];
    wire [2:0] count3 = row3[0] + row3[1] + row3[2] + row3[3];
    
    // Compute trips per row using ceil division: (a+b-1)/b
    wire [2:0] trips0 = (count0 + capacity - 1) / capacity;
    wire [2:0] trips1 = (count1 + capacity - 1) / capacity;
    wire [2:0] trips2 = (count2 + capacity - 1) / capacity;
    wire [2:0] trips3 = (count3 + capacity - 1) / capacity;
    
    // Sum trips (extend to 5 bits)
    wire [5:0] total = {1'b0, trips0} + {1'b0, trips1} + {1'b0, trips2} + {1'b0, trips3};
    assign total_trips = total[4:0];
    
endmodule