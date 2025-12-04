module max_rectangle_finder (
    input [7:0] n, m, x, y, a, b,
    output [7:0] x1, y1, x2, y2
);
    
    // Step 1: Calculate scale_x and scale_y using integer division
    wire [7:0] scale_x = n / a;
    wire [7:0] scale_y = m / b;
    
    // Step 2: Determine the limiting scale (minimum of scale_x and scale_y)
    wire [7:0] scale = (scale_x < scale_y) ? scale_x : scale_y;
    
    // Step 3: Calculate rectangle dimensions
    wire [7:0] rect_width = a * scale;   // Maximum 255, safe for 8-bit
    wire [7:0] rect_height = b * scale;  // Maximum 255, safe for 8-bit
    
    // Step 4: Calculate half dimensions
    wire [7:0] half_w = rect_width / 2;
    wire [7:0] half_h = rect_height / 2;
    
    // Step 5: Calculate initial x1 and y1
    wire [7:0] x1_temp = (x >= half_w) ? (x - half_w) : 8'd0;
    wire [7:0] y1_temp = (y >= half_h) ? (y - half_h) : 8'd0;
    
    // Step 6: Clamp x1 to ensure rectangle fits within grid width
    assign x1 = (x1_temp > (n - rect_width)) ? (n - rect_width) : x1_temp;
    
    // Step 7: Clamp y1 to ensure rectangle fits within grid height
    assign y1 = (y1_temp > (m - rect_height)) ? (m - rect_height) : y1_temp;
    
    // Step 8: Calculate right and top edges
    assign x2 = x1 + rect_width;
    assign y2 = y1 + rect_height;
    
endmodule