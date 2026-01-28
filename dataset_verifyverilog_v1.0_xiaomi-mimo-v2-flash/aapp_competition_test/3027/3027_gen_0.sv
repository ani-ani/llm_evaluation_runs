module StampMinimumNubs (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] grid_in,
    input wire [3:0] height,
    input wire [3:0] width,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] CALCULATE  = 3'd2;
    localparam [2:0] CHECK      = 3'd3;
    localparam [2:0] COUNT      = 3'd4;
    localparam [2:0] UPDATE_MIN = 3'd5;
    localparam [2:0] FINISH     = 3'd6;

    reg [2:0] state, next_state;
    
    // Internal registers
    reg [255:0] grid_reg;
    reg [3:0] h_reg, w_reg;
    reg signed [3:0] dy, dx;
    reg signed [3:0] dy_temp, dx_temp;
    reg [255:0] stamp;
    reg [255:0] shifted_stamp;
    reg [255:0] union_result;
    reg [7:0] popcount_val;
    reg [7:0] min_nubs;
    reg [7:0] cycle_count;
    reg [3:0] bit_index;
    reg bit_match;
    reg valid_offset;
    localparam [7:0] MAX_CYCLES = 8'd255;
    localparam [3:0] MAX_WIDTH = 4'd16;
    localparam [3:0] MAX_HEIGHT = 4'd16;

    // Helper to extract bit from 2D grid
    function automatic [0:0] get_bit(input signed [3:0] r, input signed [3:0] c, input [3:0] h, input [3:0] w, input [255:0] g);
        integer index;
        get_bit = 0;
        if (r >= 0 && r < h && c >= 0 && c < w) begin
            index = r * 16 + c;
            get_bit = g[255 - index];
        end
    endfunction

    // Helper to set bit in packed output
    function automatic [255:0] set_bit(input signed [3:0] r, input signed [3:0] c, input [3:0] h, input [3:0] w, input [255:0] g);
        integer index;
        set_bit = g;
        if (r >= 0 && r < h && c >= 0 && c < w) begin
            index = r * 16 + c;
            set_bit[255 - index] = 1'b1;
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            grid_reg <= 256'd0;
            h_reg <= 4'd0;
            w_reg <= 4'd0;
            dy <= 4'sd0;
            dx <= 4'sd0;
            dy_temp <= 4'sd0;
            dx_temp <= 4'sd0;
            stamp <= 256'd0;
            shifted_stamp <= 256'd0;
            union_result <= 256'd0;
            popcount_val <= 8'd0;
            min_nubs <= 8'd255;
            cycle_count <= 8'd0;
            bit_index <= 4'd0;
            bit_match <= 1'b0;
            valid_offset <= 1'b0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end else begin
                        state <= IDLE;
                    end
                end

                LOAD: begin
                    grid_reg <= grid_in;
                    h_reg <= height;
                    w_reg <= width;
                    dy <= -height + 4'sd1;
                    dx <= -width + 4'sd1;
                    min_nubs <= 8'd255;
                    state <= CALCULATE;
                end

                CALCULATE: begin
                    // Generate stamp for current offset (dy, dx)
                    // Stamp S = Grid AND (Grid shifted by (-dy, -dx))
                    // We need to check bounds: (r, c) and (r-dy, c-dx) must be in bounds
                    // S contains 1s only where BOTH grid and shifted grid have 1s
                    
                    // We'll iterate through all bits to build stamp
                    if (bit_index < (h_reg * w_reg)) begin
                        integer r, c;
                        bit_index <= bit_index + 4'd1;
                        r = bit_index / 16;
                        c = bit_index % 16;
                        
                        if (r < h_reg && c < w_reg) begin
                            // Check if (r, c) is in bounds for shifted grid
                            // shifted grid point is (r + dy, c + dx)
                            // wait, stamp is the pattern that produces Grid when stamped twice.
                            // If we have Grid and offset (dy, dx), the stamp must be:
                            // S = Grid ∩ (Grid shifted by -dy, -dx)
                            // This means for each (r, c) in Grid, we check if (r-dy, c-dx) is also in Grid.
                            
                            // To check: is (r, c) a 1 in stamp?
                            // It is a 1 if: Grid[r][c] == 1 AND Grid[r+dy][c+dx] == 1 (assuming valid bounds)
                            
                            reg g_curr, g_shifted;
                            g_curr = get_bit(r, c, h_reg, w_reg, grid_reg);
                            g_shifted = get_bit(r + dy, c + dx, h_reg, w_reg, grid_reg);
                            
                            if (g_curr && g_shifted) begin
                                stamp <= set_bit(r, c, h_reg, w_reg, stamp);
                            end
                        end
                    end else begin
                        // Done calculating stamp, reset index for next stage
                        bit_index <= 4'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    // Verify that Union of S and S shifted by (dy, dx) equals Grid
                    // Also verify both S and shifted S are within bounds (implicitly checked by generation)
                    
                    if (bit_index < (h_reg * w_reg)) begin
                        integer r, c;
                        bit_index <= bit_index + 4'd1;
                        r = bit_index / 16;
                        c = bit_index % 16;
                        
                        if (r < h_reg && c < w_reg) begin
                            reg g_val;
                            reg s_val;
                            reg ss_val; // shifted stamp value
                            reg union_val;
                            
                            g_val = get_bit(r, c, h_reg, w_reg, grid_reg);
                            s_val = get_bit(r, c, h_reg, w_reg, stamp);
                            ss_val = get_bit(r - dy, c - dx, h_reg, w_reg, stamp);
                            union_val = s_val | ss_val;
                            
                            if (union_val != g_val) begin
                                valid_offset <= 1'b0;
                            end else if (valid_offset != 1'b0) begin
                                // Only set to 1 if we haven't failed yet
                                valid_offset <= 1'b1;
                            end
                            
                            // Initial valid_offset check
                            if (bit_index == 1) begin
                                valid_offset <= 1'b1;
                            end
                        end
                    end else begin
                        if (valid_offset) begin
                            state <= COUNT;
                        end else begin
                            // Move to next offset
                            state <= UPDATE_MIN;
                        end
                        bit_index <= 4'd0;
                    end
                end

                COUNT: begin
                    // Calculate popcount of stamp
                    // Using binary expansion method
                    if (bit_index < 8) begin
                        reg [31:0] temp_low, temp_high;
                        bit_index <= bit_index + 4'd1;
                        
                        // Count 1s in 32-bit chunks
                        // This is a simplified counter, in hardware you'd use dedicated popcount logic
                        // Here we simulate iteration
                        temp_low = stamp[31:0];
                        temp_high = stamp[63:32];
                        // Actually, for 256 bits, we need a loop.
                        // Since this is sequential logic, let's use a single cycle popcount
                        // or iterative. Let's use iterative bit slicing.
                    end else begin
                        // Use a simpler popcount calculation
                        // Calculate popcount of stamp
                        integer i;
                        popcount_val <= 8'd0;
                        for (i = 0; i < 256; i = i + 1) begin
                            if (stamp[i]) begin
                                popcount_val <= popcount_val + 8'd1;
                            end
                        end
                        state <= UPDATE_MIN;
                    end
                end
                
                UPDATE_MIN: begin
                    if (popcount_val < min_nubs && valid_offset) begin
                        min_nubs <= popcount_val;
                    end
                    
                    // Reset for next iteration or finish
                    stamp <= 256'd0;
                    valid_offset <= 1'b0;
                    popcount_val <= 8'd0;
                    
                    // Increment dx and dy
                    // Loop dx: -w+1 to w-1
                    // Loop dy: -h+1 to h-1
                    
                    if (dx < w_reg - 4'sd1) begin
                        dx <= dx + 4'sd1;
                        state <= CALCULATE;
                    end else begin
                        dx <= -w_reg + 4'sd1;
                        if (dy < h_reg - 4'sd1) begin
                            dy <= dy + 4'sd1;
                            state <= CALCULATE;
                        end else begin
                            state <= FINISH;
                        end
                    end
                end

                FINISH: begin
                    result <= min_nubs;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule