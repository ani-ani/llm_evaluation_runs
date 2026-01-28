module SunlightCalculator (
    input clk,
    input rst_n,
    input start,
    input [15:0] building_x,
    input [15:0] building_h,
    input input_valid,
    input input_done,
    output reg [15:0] result,
    output reg [3:0] result_index,
    output reg result_valid,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] COLLECT     = 3'd1;
    localparam [2:0] INIT_PROC   = 3'd2;
    localparam [2:0] OUTER_LOOP  = 3'd3;
    localparam [2:0] INNER_LOOP  = 3'd4;
    localparam [2:0] CALC_ANGLE  = 3'd5;
    localparam [2:0] OUTPUT_RES  = 3'd6;
    localparam [2:0] DONE_STATE  = 3'd7;

    // Fixed-point constants
    localparam [15:0] FIXED_SCALE = 16'd64;    // Q8.8 scaling factor
    localparam [15:0] MAX_OUTPUT  = 16'd180;   // Max hours
    localparam [7:0]  MAX_N       = 8'd16;
    localparam [7:0]  MAX_CYCLES  = 8'd200;    // Safety counter

    // Registers
    reg [2:0]  state, next_state;
    reg [7:0]  n_count;            // Number of buildings collected
    reg [3:0]  i_idx;              // Outer loop index
    reg [3:0]  j_idx;              // Inner loop index
    reg [15:0] min_angle_reg;      // Min angle for current building i
    reg [7:0]  cycle_counter;      // Safety cycle counter
    reg        is_west;            // Flag for direction
    reg        valid_angle;        // Flag if current angle is valid (>0)
    reg        calc_done;          // Flag for calculation completion
    
    // Result tracking
    reg [15:0] temp_result;
    
    // Arrays (synthesized as distributed RAM)
    reg [15:0] x_ram [0:15];
    reg [15:0] h_ram [0:15];
    reg [15:0] min_angle_ram [0:15];
    
    // Intermediate calculation registers
    reg [15:0] x_diff;
    reg [15:0] h_diff;
    reg [31:0] numerator;  // For fixed-point multiplication
    reg [31:0] angle_temp;
    
    integer idx_init;
    integer i_loop, j_loop;

    // Reset and State Update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_count <= 8'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            min_angle_reg <= 16'd0;
            cycle_counter <= 8'd0;
            is_west <= 1'b0;
            valid_angle <= 1'b0;
            calc_done <= 1'b0;
            temp_result <= 16'd0;
            result <= 16'd0;
            result_index <= 4'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            x_diff <= 16'd0;
            h_diff <= 16'd0;
            numerator <= 32'd0;
            angle_temp <= 32'd0;
            
            // Initialize arrays to 0
            for (idx_init = 0; idx_init < 16; idx_init = idx_init + 1) begin
                x_ram[idx_init] <= 16'd0;
                h_ram[idx_init] <= 16'd0;
                min_angle_ram[idx_init] <= 16'd0;
            end
        end else begin
            state <= next_state;
            
            // Clear single-cycle outputs
            result_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_counter <= 8'd0;
                    calc_done <= 1'b0;
                    if (start) begin
                        n_count <= 8'd0;
                        i_idx <= 4'd0;
                    end
                end
                
                COLLECT: begin
                    if (input_valid && n_count < MAX_N) begin
                        x_ram[n_count] <= building_x;
                        h_ram[n_count] <= building_h;
                        n_count <= n_count + 8'd1;
                    end
                end
                
                INIT_PROC: begin
                    // Initialize min_angle_ram to 0 (full sun initially)
                    for (i_loop = 0; i_loop < 16; i_loop = i_loop + 1) begin
                        min_angle_ram[i_loop] <= 16'd0;
                    end
                    i_idx <= 4'd0;
                    j_idx <= 4'd0;
                    cycle_counter <= 8'd0;
                end
                
                OUTER_LOOP: begin
                    if (i_idx < n_count[3:0]) begin
                        min_angle_reg <= min_angle_ram[i_idx];
                        j_idx <= 4'd0;
                    end
                end
                
                INNER_LOOP: begin
                    if (j_idx < n_count[3:0]) begin
                        cycle_counter <= cycle_counter + 8'd1;
                        if (j_idx != i_idx) begin
                            // Determine direction
                            if (x_ram[j_idx] < x_ram[i_idx]) begin
                                is_west <= 1'b1;
                                x_diff <= x_ram[i_idx] - x_ram[j_idx];
                                h_diff <= h_ram[i_idx] - h_ram[j_idx];
                            end else if (x_ram[j_idx] > x_ram[i_idx]) begin
                                is_west <= 1'b0;
                                x_diff <= x_ram[j_idx] - x_ram[i_idx];
                                h_diff <= h_ram[i_idx] - h_ram[j_idx];
                            end else begin
                                // Same x coordinate, no obstruction
                                valid_angle <= 1'b0;
                            end
                        end
                    end
                end
                
                CALC_ANGLE: begin
                    // Calculate angle = (h_diff / x_diff) * FIXED_SCALE
                    // Using approximation: numerator = h_diff * FIXED_SCALE
                    // Angle = numerator / x_diff
                    if (x_diff != 16'd0 && h_diff > 16'd0 && (j_idx != i_idx)) begin
                        numerator <= h_diff * FIXED_SCALE;
                        // Wait one cycle for division simulation
                        // In real hardware, this would be a pipelined divider
                        // Here we use sequential approximation
                    end
                    
                    // Check validity of angle (must be positive height diff)
                    valid_angle <= (h_diff > 16'd0) && (x_diff != 16'd0);
                end
                
                OUTPUT_RES: begin
                    // Calculate final result: 180 - min_angle
                    temp_result <= (MAX_OUTPUT > min_angle_reg) ? (MAX_OUTPUT - min_angle_reg) : 16'd0;
                    result_index <= i_idx;
                    result_valid <= 1'b1;
                    i_idx <= i_idx + 4'd1;
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    result <= temp_result;
                    // Stream next results in subsequent cycles
                    if (i_idx < n_count[3:0]) begin
                        // Continue outputting
                        next_state <= OUTPUT_RES;
                    end
                end
            endcase
            
            // Update min_angle for building i in OUTPUT_RES state
            if (state == CALC_ANGLE && valid_angle) begin
                // Fixed-point division approximation
                // Since we can't use real division in Icarus, use shift approximation
                // angle_temp = numerator / x_diff
                // We'll use a simple subtractive approximation
                angle_temp <= (numerator >> 4); // Rough approx: /16
                
                // Compare and update min_angle_reg
                // Note: This comparison happens in the same cycle for simplicity
                // In real design, would need pipeline registers
                if ((numerator >> 4) > min_angle_reg && (numerator >> 4) < 180) begin
                    min_angle_ram[i_idx] <= numerator[19:4]; // Take middle 16 bits
                    min_angle_reg <= numerator[19:4];
                end
            end
            
            if (state == OUTPUT_RES) begin
                result <= temp_result;
            end
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) next_state = COLLECT;
            end
            
            COLLECT: begin
                if (input_done) next_state = INIT_PROC;
            end
            
            INIT_PROC: begin
                if (n_count > 8'd0) next_state = OUTER_LOOP;
                else next_state = DONE_STATE;
            end
            
            OUTER_LOOP: begin
                if (i_idx < n_count[3:0]) next_state = INNER_LOOP;
                else next_state = DONE_STATE;
            end
            
            INNER_LOOP: begin
                if (j_idx < n_count[3:0]) begin
                    if (j_idx != i_idx) next_state = CALC_ANGLE;
                    else next_state = INNER_LOOP; // Skip self
                end else begin
                    next_state = OUTPUT_RES;
                end
            end
            
            CALC_ANGLE: begin
                next_state = INNER_LOOP; // Continue inner loop
            end
            
            OUTPUT_RES: begin
                next_state = DONE_STATE;
            end
            
            DONE_STATE: begin
                if (i_idx < n_count[3:0]) next_state = OUTPUT_RES;
                else next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
        
        // Safety timeout
        if (cycle_counter >= MAX_CYCLES) next_state = DONE_STATE;
    end

endmodule