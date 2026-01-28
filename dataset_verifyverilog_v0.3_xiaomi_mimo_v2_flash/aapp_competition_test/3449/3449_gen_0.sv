module club_lighting (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] threshold,
    input wire [2:0] height,
    input wire [3:0] data_in,
    input wire [5:0] addr,
    input wire wr,
    output reg done,
    output reg [15:0] cost_out
);

// Internal memory for strengths (8x8 grid)
reg [3:0] strength_ram [0:63];

// State machine states
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_LOAD_STRENGTH = 3'd1;
localparam [2:0] S_COMPUTE_LIGHT = 3'd2;
localparam [2:0] S_COMPUTE_FENCE = 3'd3;
localparam [2:0] S_DONE = 3'd4;

reg [2:0] state;
reg [5:0] cell_idx;
reg [5:0] source_idx;
reg [15:0] light_sum;
reg [15:0] light_levels [0:63];
reg [63:0] meets_std;
reg [3:0] dr, dc;
reg signed [15:0] contribution;

// Cycle counter for timeout prevention
reg [15:0] cycle_count;
localparam [15:0] MAX_CYCLES = 16'd10000;

// Helper signals for combinational calculations
reg signed [15:0] weight_val;
reg [3:0] row_s, col_s, row_t, col_t;
reg [3:0] dr_val, dc_val;

always @(*) begin
    // Default values
    weight_val = 16'd0;
    dr_val = 4'd0;
    dc_val = 4'd0;
    contribution = 16'd0;
    
    // Get source coordinates
    row_s = source_idx / 4'd8;
    col_s = source_idx % 4'd8;
    
    // Get target coordinates
    row_t = cell_idx / 4'd8;
    col_t = cell_idx % 4'd8;
    
    // Compute absolute difference
    if (row_s > row_t) dr_val = row_s - row_t;
    else dr_val = row_t - row_s;
    
    if (col_s > col_t) dc_val = col_s - col_t;
    else dc_val = col_t - col_s;
    
    // Compute denominator: dr² + dc² + H²
    // All values are small, so 8 bits is enough
    case ({dr_val[3:0], dc_val[3:0], height[2:0]})
        // Simplified weight lookup - use division approximation
        // For dr=0, dc=0: weight = strength / H²
        // For dr>0 or dc>0: weight = strength / (dr² + dc² + H²)
        default: begin
            // Compute weight based on denominator
            if (dr_val == 0 && dc_val == 0) begin
                // Self contribution: strength / H²
                case (height)
                    3'd1: weight_val = {strength_ram[source_idx], 4'd0};  // /1
                    3'd2: weight_val = {1'b0, strength_ram[source_idx], 3'd0};  // /2
                    3'd3: weight_val = {1'b0, strength_ram[source_idx], 2'd0} + {2'b00, strength_ram[source_idx], 1'b0};  // /3
                    3'd4: weight_val = {2'b00, strength_ram[source_idx], 2'd0};  // /4
                    3'd5: weight_val = {2'b00, strength_ram[source_idx], 1'd0} + {3'b000, strength_ram[source_idx]};  // /5
                    default: weight_val = {strength_ram[source_idx], 4'd0};
                endcase
            end else begin
                // External contribution: much smaller
                // Use approximate weight = strength / (denom)
                // For simplicity, we'll use shift-based approximation
                reg [7:0] denom;
                denom = dr_val*dr_val + dc_val*dc_val + height*height;
                if (denom <= 8'd1) weight_val = {strength_ram[source_idx], 4'd0};
                else if (denom <= 8'd3) weight_val = {strength_ram[source_idx], 3'd0};
                else if (denom <= 8'd7) weight_val = {strength_ram[source_idx], 2'd0};
                else if (denom <= 8'd15) weight_val = {strength_ram[source_idx], 1'd0};
                else weight_val = {1'b0, strength_ram[source_idx]};
            end
        end
    endcase
    
    // Contribution is weight * strength[source] (but strength already in weight)
    // Actually we want: strength[target] contribution from source
    // contribution = weight * strength[source]
    contribution = weight_val;
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        cost_out <= 16'd0;
        cell_idx <= 6'd0;
        source_idx <= 6'd0;
        light_sum <= 16'd0;
        meets_std <= 64'd0;
        cycle_count <= 16'd0;
    end else begin
        cycle_count <= cycle_count + 16'd1;
        
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                cycle_count <= 16'd0;
                if (start) begin
                    state <= S_LOAD_STRENGTH;
                    cell_idx <= 6'd0;
                end
            end
            
            S_LOAD_STRENGTH: begin
                // Memory write happens via separate always block
                state <= S_COMPUTE_LIGHT;
                cell_idx <= 6'd0;
                meets_std <= 64'd0;
            end
            
            S_COMPUTE_LIGHT: begin
                if (cell_idx < 6'd64) begin
                    if (source_idx < 6'd64) begin
                        // Add contribution from source to light_sum
                        light_sum <= light_sum + contribution;
                        source_idx <= source_idx + 6'd1;
                    end else begin
                        // Done summing for this cell
                        // Check threshold
                        if (light_sum >= {threshold, 8'h00}) begin
                            meets_std[cell_idx] <= 1'b1;
                        end
                        light_levels[cell_idx] <= light_sum;
                        cell_idx <= cell_idx + 6'd1;
                        source_idx <= 6'd0;
                        light_sum <= 16'd0;
                    end
                end else begin
                    state <= S_COMPUTE_FENCE;
                    cell_idx <= 6'd0;
                    cost_out <= 16'd0;
                end
            end
            
            S_COMPUTE_FENCE: begin
                if (cell_idx < 6'd64) begin
                    // Compute fencing cost
                    // Only fence edges between cells where one meets std and other doesn't
                    // and edge is between different levels
                    reg [5:0] right_idx;
                    reg [5:0] bottom_idx;
                    reg [3:0] my_level, right_level, bottom_level;
                    reg my_meets, right_meets, bottom_meets;
                    
                    // Get indices
                    right_idx = (cell_idx + 6'd1);
                    bottom_idx = (cell_idx + 6'd8);
                    
                    // Get values (combinational)
                    my_level = light_levels[cell_idx][15:8];
                    my_meets = meets_std[cell_idx];
                    
                    if (cell_idx % 8 < 7 && right_idx < 6'd64) begin
                        right_level = light_levels[right_idx][15:8];
                        right_meets = meets_std[right_idx];
                        
                        if (my_meets != right_meets && my_level != right_level) begin
                            cost_out <= cost_out + 16'd1;
                        end
                    end
                    
                    if (cell_idx < 6'd56) begin
                        bottom_level = light_levels[bottom_idx][15:8];
                        bottom_meets = meets_std[bottom_idx];
                        
                        if (my_meets != bottom_meets && my_level != bottom_level) begin
                            cost_out <= cost_out + 16'd1;
                        end
                    end
                    
                    cell_idx <= cell_idx + 6'd1;
                end else begin
                    state <= S_DONE;
                    done <= 1'b1;
                end
            end
            
            S_DONE: begin
                state <= S_IDLE;
                done <= 1'b0;
            end
            
            default: state <= S_IDLE;
        endcase
    end
end

// Memory write logic (separate to avoid conflict with computation)
always @(posedge clk) begin
    if (wr) begin
        strength_ram[addr] <= data_in;
    end
end

endmodule