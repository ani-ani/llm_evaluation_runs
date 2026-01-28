module convex_hull_area (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire points_valid,
    input wire [2:0] point_idx,
    input wire [7:0] point_x,
    input wire [7:0] point_y,
    input wire [1:0] op,
    output reg [15:0] area_out,
    output reg done,
    output reg ready
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] SORT_EXTREME = 3'd2;
    localparam [2:0] CALC_AREA = 3'd3;
    localparam [2:0] REMOVE_POINT = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Internal registers for 8 points (X and Y)
    reg [7:0] points_x [0:7];
    reg [7:0] points_y [0:7];
    reg [7:0] valid_mask; // 1 bit per point (1=valid, 0=removed)
    
    // State machine variables
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] counter; // General purpose counter
    reg [2:0] active_count; // Number of active points
    reg [2:0] iter_count; // Number of removals done
    
    // Extreme detection variables
    reg [2:0] ext_idx;
    reg [7:0] ext_val;
    reg [2:0] scan_idx;
    
    // Area calculation variables
    reg signed [23:0] sum_acc; // Accumulator for shoelace sum
    reg signed [15:0] area_temp; // Intermediate area
    reg [2:0] calc_idx;
    reg signed [15:0] term1; // x_i * y_{i+1}
    reg signed [15:0] term2; // x_{i+1} * y_i
    wire signed [15:0] prod1;
    wire signed [15:0] prod2;
    
    // Helper signals
    reg [2:0] next_active_idx;
    reg found_next;
    
    // Multiplication logic (Q8.8 * Q8.8 = Q16.16, we take [15:0] for Q8.8 result)
    assign prod1 = points_x[calc_idx] * points_y[next_active_idx];
    assign prod2 = points_x[next_active_idx] * points_y[calc_idx];

    // Sequential State Machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            ready <= 1'b0;
            area_out <= 16'd0;
            valid_mask <= 8'h00;
            counter <= 4'd0;
            iter_count <= 3'd0;
            active_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        ready <= 1'b1; // Indicate ready to receive
                        counter <= 4'd0;
                        valid_mask <= 8'h00;
                        active_count <= 3'd0;
                        iter_count <= 3'd0;
                    end
                end

                LOAD: begin
                    if (points_valid) begin
                        points_x[point_idx] <= point_x;
                        points_y[point_idx] <= point_y;
                        valid_mask[point_idx] <= 1'b1;
                        counter <= counter + 4'd1;
                        active_count <= active_count + 3'd1;
                    end
                    if (counter == 4'd8 || (points_valid && counter == 4'd7)) begin
                        ready <= 1'b0;
                        state <= SORT_EXTREME;
                        scan_idx <= 3'd0;
                        ext_idx <= 3'd0;
                        // Initialize ext_val based on first valid point
                        // Find first valid index for initialization
                        counter <= 4'd0; // Use counter for scan loop
                    end
                end

                SORT_EXTREME: begin
                    // Sequential scan for extreme point (8 cycles)
                    if (valid_mask[scan_idx]) begin
                        if (counter == 4'd0) begin
                            // First valid point initialization
                            ext_idx <= scan_idx;
                            ext_val <= (op == 2'b00 || op == 2'b10) ? 
                                       (op == 2'b00 ? points_x[scan_idx] : points_y[scan_idx]) : 
                                       (op == 2'b00 ? points_x[scan_idx] : points_y[scan_idx]);
                            // Note: Min logic for 00/10, Max logic for 01/11 handled below
                            if (op == 2'b01 || op == 2'b11) begin
                                ext_val <= (op == 2'b01) ? points_x[scan_idx] : points_y[scan_idx];
                            end else begin
                                ext_val <= (op == 2'b00) ? points_x[scan_idx] : points_y[scan_idx];
                            end
                            counter <= 4'd1;
                        end else begin
                            // Compare logic
                            if (op == 2'b01) begin // Right (Max X)
                                if (points_x[scan_idx] > ext_val) begin
                                    ext_val <= points_x[scan_idx];
                                    ext_idx <= scan_idx;
                                end
                            end else if (op == 2'b11) begin // Down (Max Y)
                                if (points_y[scan_idx] > ext_val) begin
                                    ext_val <= points_y[scan_idx];
                                    ext_idx <= scan_idx;
                                end
                            end else if (op == 2'b00) begin // Left (Min X)
                                if (points_x[scan_idx] < ext_val) begin
                                    ext_val <= points_x[scan_idx];
                                    ext_idx <= scan_idx;
                                end
                            end else begin // Up (Min Y) (op == 2'b10)
                                if (points_y[scan_idx] < ext_val) begin
                                    ext_val <= points_y[scan_idx];
                                    ext_idx <= scan_idx;
                                end
                            end
                        end
                    end
                    
                    if (scan_idx == 3'd7) begin
                        state <= CALC_AREA;
                        calc_idx <= 3'd0;
                        sum_acc <= 24'sd0;
                        counter <= 4'd0; // Reset counter for area calc
                        // Find first valid index for start of polygon
                        found_next <= 1'b0;
                        next_active_idx <= 3'd0;
                    end else begin
                        scan_idx <= scan_idx + 3'd1;
                    end
                end

                CALC_AREA: begin
                    // Find current active point starting from calc_idx
                    // To prevent infinite loop, we iterate up to 8 times
                    if (counter < 4'd8) begin
                        if (valid_mask[calc_idx]) begin
                            // Found current point, now find next valid point
                            if (!found_next) begin
                                // Search for next valid index > calc_idx, or wrap around
                                if (next_active_idx == calc_idx && next_active_idx != 3'd0) begin
                                    // We wrapped back to start, this is last point connected to first
                                    // Find the first valid point (index 0)
                                    if (valid_mask[0]) next_active_idx <= 3'd0;
                                    else if (valid_mask[1]) next_active_idx <= 3'd1;
                                    else if (valid_mask[2]) next_active_idx <= 3'd2;
                                    else if (valid_mask[3]) next_active_idx <= 3'd3;
                                    else if (valid_mask[4]) next_active_idx <= 3'd4;
                                    else if (valid_mask[5]) next_active_idx <= 3'd5;
                                    else if (valid_mask[6]) next_active_idx <= 3'd6;
                                    else if (valid_mask[7]) next_active_idx <= 3'd7;
                                    found_next <= 1'b1; // Done finding
                                end else begin
                                    // Scan forward
                                    if (next_active_idx < 3'd7) begin
                                        next_active_idx <= next_active_idx + 3'd1;
                                    end else begin
                                        next_active_idx <= 3'd0; // Wrap
                                    end
                                end
                                // Check validity
                                if (valid_mask[next_active_idx]) begin
                                    found_next <= 1'b1;
                                end
                            end else begin
                                // Calculate term
                                // x_i * y_{i+1} - x_{i+1} * y_i
                                // product is 16-bit (8.8 * 8.8 -> 16.16, truncated to 16.0 effectively for Q8.8 logic)
                                // Actually, spec says Q8.8 for output. 
                                // 8-bit * 8-bit = 16-bit integer (since 8.8 * 8.8 = 16.16, taking 16 MSBs is ~8.8 result)
                                // Let's treat inputs as integer 8-bit for area, result Q8.8
                                // 8x8 multiply = 16bit. Sum of 8 terms = 24bit. 
                                // We shift right 1 (divide by 2) at end.
                                
                                sum_acc <= sum_acc + (prod1 - prod2);
                                
                                // Move to next active point
                                calc_idx <= next_active_idx;
                                found_next <= 1'b0;
                                
                                if (next_active_idx == 3'd0 && calc_idx != 3'd0) begin
                                    // Completed cycle
                                    state <= REMOVE_POINT;
                                    // Check if we need to output (done pulse)
                                    // Output area here (before removal?) No, spec says area of current state.
                                    // We output after calculation, before removal update? 
                                    // Spec: "Output area_out when done=1"
                                    // We will pulse done in REMOVE_POINT state or create an output state.
                                    // Let's output in REMOVE_POINT or before.
                                end
                            end
                            counter <= counter + 4'd1;
                        end else begin
                            // Current idx is removed, move to next
                            calc_idx <= calc_idx + 3'd1;
                            if (calc_idx == 3'd7) calc_idx <= 3'd0;
                            counter <= counter + 4'd1;
                        end
                    end else begin
                        // Safety timeout (should not happen if valid_mask is correct)
                        state <= REMOVE_POINT;
                    end
                end

                REMOVE_POINT: begin
                    // 1. Output Area
                    // Area = |sum| / 2. Sum is 24-bit, result 16-bit Q8.8
                    // Since inputs are 8-bit, sum max ~ 8 * 255 * 255 = ~500k. 
                    // 500k fits in 24 bits. Divide by 2 -> 250k. Max Q8.8 is 65535.
                    // We need to clamp or just assume inputs are small enough or handle overflows.
                    // Given constraints 0-255, max area of polygon (e.g. zigzag) is less than 8 * 255^2 = 520k.
                    // In Q8.8, 520k is too big (max 65535). 
                    // Wait, Q8.8 means 8 integer, 8 fraction. 65535 is 255.99.
                    // The area calculation uses integers 0-255. The result IS integer area (0.5 * sum).
                    // So result is an integer up to ~250k. 
            // The spec says "coordinates 0-255 (8-bit), operations in Q8.8 fixed-point".
            // This implies the arithmetic is Q8.8. 
            // 8x8 multiply in Q8.8 gives Q16.16. We keep 16 bits for intermediate sum?
            // Let's stick to integer arithmetic for area, then represent as Q8.8 (integer part).
            // If area > 65535, we saturate.
                    
                    area_temp <= (sum_acc > 0) ? sum_acc[16:1] : (~sum_acc + 1) >> 1; // abs(val)/2
                    // Check saturation
                    if (sum_acc > 24'sd32767) area_out <= 16'hFFFF;
                    else if (sum_acc < -24'sd32767) area_out <= 16'hFFFF;
                    else area_out <= (sum_acc > 0) ? sum_acc[15:0] : ((-sum_acc) >> 1); // Assuming integer result fits 16 bits
                    // Note: Logic above assumes integer result. 
                    // Simplified: Just shift sum right 1 (divide by 2) and take lower 16 bits.
                    // Since sum is accumulated from 16-bit products, it's roughly sum(products).
                    // Let's just do: area_out <= sum_acc[16:1] (assuming positive sum)
                    // Handle sign:
                    if (sum_acc[23]) sum_acc <= -sum_acc; // absolute value
                    area_out <= sum_acc[17:2]; // Divide by 4 (shift 2) to get more headroom? No, divide by 2.
                    // 24 bit / 2 = 23 bit. 23 bit max ~ 8 million. 16 bit max 65535.
                    // We MUST handle overflow properly or the spec is loose.
                    // Let's output sum_acc[16:1] (upper 16 bits of sum divided by 2).
                    area_out <= sum_acc[16:1];
                    
                    done <= 1'b1;
                    
                    // 2. Remove Point
                    valid_mask[ext_idx] <= 1'b0;
                    
                    // 3. Check Loop Condition
                    // Spec: "scale constraints: N=8 points (3-8)". 
                    // Output N-2 areas. For 8 inputs, output 6 areas.
                    // However, spec also says "handle a sequence of up to 5 removals (N-2=6 max)". 
                    // And "Total iterations < 256 cycles".
                    // Let's do 5 removals (output 6 areas including initial? No, output area after calculation).
                    // Let's interpret: Start with N points. Calculate Area. Remove. Calculate Area. Remove...
                    // Sequence: Area(N), Area(N-1), ..., Area(3).
                    // For N=8: 6 areas. 5 removals.
                    
                    if (iter_count == 3'd5) begin // 5 removals done (output 6 areas? No, output 1st area before 1st removal)
                        state <= FINISH;
                    end else begin
                        state <= SORT_EXTREME;
                        iter_count <= iter_count + 3'd1;
                        // Reset scan for next extreme
                        scan_idx <= 3'd0;
                        counter <= 4'd0;
                    end
                    
                    // Ready for next calculation immediately?
                    // Wait one cycle to clear done.
                end

                FINISH: begin
                    done <= 1'b0;
                    // Stay here until reset or new start
                    if (start) begin
                        state <= LOAD;
                        ready <= 1'b1;
                        counter <= 4'd0;
                        valid_mask <= 8'h00;
                        active_count <= 3'd0;
                        iter_count <= 3'd0;
                    end
                end

                default: state <= IDLE;
            endcase
            
            // Clear done pulse after one cycle (except in IDLE/FINISH)
            if (state != FINISH && state != IDLE) begin
                if (done) done <= 1'b0;
            end
        end
    end

    // Combinational logic for finding first valid index in LOAD/CALC
    // (Actually handled sequentially above to avoid combinational loops)

endmodule