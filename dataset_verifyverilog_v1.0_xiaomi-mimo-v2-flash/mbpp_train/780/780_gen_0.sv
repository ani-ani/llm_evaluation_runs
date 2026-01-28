module pairwise_sum (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] coords_x [0:7],
    input wire [15:0] coords_y [0:7],
    input wire [3:0] num_coords,
    output reg [15:0] result_pairs_x [0:7],
    output reg [15:0] result_pairs_y [0:7],
    output reg [3:0] num_results,
    output reg done,
    output reg valid,
    output reg overflow
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal registers
    reg [2:0] state, next_state;
    reg [15:0] stored_coords_x [0:7];
    reg [15:0] stored_coords_y [0:7];
    reg [3:0] i_counter;  // Outer loop index
    reg [3:0] j_counter;  // Inner loop index
    reg [3:0] result_idx;
    reg [5:0] computed_count;  // Can hold up to 28
    reg [5:0] max_pairs;
    reg computation_done;

    // Cycle counter for timeout prevention
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd200;

    integer idx;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            for (idx = 0; idx < 8; idx = idx + 1) begin
                stored_coords_x[idx] <= 16'd0;
                stored_coords_y[idx] <= 16'd0;
                result_pairs_x[idx] <= 16'd0;
                result_pairs_y[idx] <= 16'd0;
            end
            i_counter <= 4'd0;
            j_counter <= 4'd0;
            result_idx <= 4'd0;
            computed_count <= 6'd0;
            num_results <= 4'd0;
            done <= 1'b0;
            valid <= 1'b0;
            overflow <= 1'b0;
            cycle_counter <= 8'd0;
            max_pairs <= 6'd0;
            computation_done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    overflow <= 1'b0;
                    cycle_counter <= 8'd0;
                    if (start) begin
                        computation_done <= 1'b0;
                    end
                end
                
                LOAD: begin
                    // Store input coordinates
                    for (idx = 0; idx < 8; idx = idx + 1) begin
                        if (idx < num_coords) begin
                            stored_coords_x[idx] <= coords_x[idx];
                            stored_coords_y[idx] <= coords_y[idx];
                        end else begin
                            stored_coords_x[idx] <= 16'd0;
                            stored_coords_y[idx] <= 16'd0;
                        end
                    end
                    
                    // Calculate maximum pairs and check overflow
                    if (num_coords >= 2) begin
                        max_pairs <= (num_coords * (num_coords - 4'd1)) / 6'd2;
                        if ((num_coords * (num_coords - 4'd1)) / 6'd2 > 8) begin
                            overflow <= 1'b1;
                        end
                    end else begin
                        max_pairs <= 6'd0;
                        overflow <= 1'b0;
                    end
                    
                    i_counter <= 4'd0;
                    j_counter <= 4'd1;
                    result_idx <= 4'd0;
                    computed_count <= 6'd0;
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    // Generate combination and compute sum
                    if (!computation_done && (i_counter < num_coords - 4'd1) && (j_counter < num_coords) && (result_idx < 8)) begin
                        // Store result
                        result_pairs_x[result_idx] <= stored_coords_x[i_counter] + stored_coords_x[j_counter];
                        result_pairs_y[result_idx] <= stored_coords_y[i_counter] + stored_coords_y[j_counter];
                        
                        result_idx <= result_idx + 4'd1;
                        computed_count <= computed_count + 6'd1;
                        
                        // Increment indices
                        j_counter <= j_counter + 4'd1;
                        
                        // Check if inner loop finished
                        if (j_counter == num_coords - 4'd1) begin
                            i_counter <= i_counter + 4'd1;
                            j_counter <= i_counter + 4'd2;
                        end
                        
                        // Check if all pairs computed or output limit reached
                        if (result_idx == 8'd7) begin
                            computation_done <= 1'b1;
                        end else if (i_counter >= num_coords - 4'd1) begin
                            computation_done <= 1'b1;
                        end
                    end else begin
                        computation_done <= 1'b1;
                    end
                end
                
                OUTPUT: begin
                    // Set output count
                    if (overflow) begin
                        num_results <= 4'd8;
                    end else begin
                        num_results <= computed_count[3:0];
                    end
                    valid <= 1'b1;
                end
                
                DONE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            IDLE: begin
                if (start) begin
                    if (num_coords < 2) begin
                        // Special case: less than 2 coordinates
                        next_state = DONE;
                    end else begin
                        next_state = LOAD;
                    end
                end
            end
            
            LOAD: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // Continue computation until done or timeout
                if (computation_done || cycle_counter >= MAX_CYCLES) begin
                    next_state = OUTPUT;
                end else begin
                    next_state = COMPUTE;
                end
            end
            
            OUTPUT: begin
                next_state = DONE;
            end
            
            DONE: begin
                // Return to IDLE after done pulse
                next_state = IDLE;
            end
            
            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule