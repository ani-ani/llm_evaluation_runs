module TollOptimizer (
    input clk,
    input rst_n,
    input start,
    input [15:0] entrance_i [0:15],
    input [15:0] exit_i [0:15],
    input [3:0] num_trucks,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] SORTING   = 2'd1;
    localparam [1:0] COMPUTING = 2'd2;
    localparam [1:0] FINISH    = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] sort_idx;           // Counter for sorting passes
    reg [3:0] compute_idx;        // Counter for computation
    reg [3:0] cycle_counter;      // Safety counter
    localparam [3:0] MAX_CYCLES = 4'd15;

    // Internal registers for sorted arrays
    reg [15:0] sorted_entrance [0:15];
    reg [15:0] sorted_exit [0:15];
    
    // Temporary storage for bubble sort swap
    reg [15:0] temp_swap;
    
    // Accumulator
    reg [31:0] accumulator;
    
    // Swap logic flag for bubble sort
    reg swap_flag;
    
    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            sort_idx <= 4'd0;
            compute_idx <= 4'd0;
            cycle_counter <= 4'd0;
            accumulator <= 32'd0;
            swap_flag <= 1'b0;
            // Initialize sorted arrays
            for (int i = 0; i < 16; i = i + 1) begin
                sorted_entrance[i] <= 16'd0;
                sorted_exit[i] <= 16'd0;
            end
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    accumulator <= 32'd0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        if (num_trucks == 4'd0) begin
                            // Handle edge case: 0 trucks
                            state <= FINISH;
                        end else begin
                            // Initialize sorted arrays with inputs
                            sorted_entrance[0] <= entrance_i[0];
                            sorted_entrance[1] <= entrance_i[1];
                            sorted_entrance[2] <= entrance_i[2];
                            sorted_entrance[3] <= entrance_i[3];
                            sorted_entrance[4] <= entrance_i[4];
                            sorted_entrance[5] <= entrance_i[5];
                            sorted_entrance[6] <= entrance_i[6];
                            sorted_entrance[7] <= entrance_i[7];
                            sorted_entrance[8] <= entrance_i[8];
                            sorted_entrance[9] <= entrance_i[9];
                            sorted_entrance[10] <= entrance_i[10];
                            sorted_entrance[11] <= entrance_i[11];
                            sorted_entrance[12] <= entrance_i[12];
                            sorted_entrance[13] <= entrance_i[13];
                            sorted_entrance[14] <= entrance_i[14];
                            sorted_entrance[15] <= entrance_i[15];
                            
                            sorted_exit[0] <= exit_i[0];
                            sorted_exit[1] <= exit_i[1];
                            sorted_exit[2] <= exit_i[2];
                            sorted_exit[3] <= exit_i[3];
                            sorted_exit[4] <= exit_i[4];
                            sorted_exit[5] <= exit_i[5];
                            sorted_exit[6] <= exit_i[6];
                            sorted_exit[7] <= exit_i[7];
                            sorted_exit[8] <= exit_i[8];
                            sorted_exit[9] <= exit_i[9];
                            sorted_exit[10] <= exit_i[10];
                            sorted_exit[11] <= exit_i[11];
                            sorted_exit[12] <= exit_i[12];
                            sorted_exit[13] <= exit_i[13];
                            sorted_exit[14] <= exit_i[14];
                            sorted_exit[15] <= exit_i[15];
                            
                            sort_idx <= 4'd0;
                            compute_idx <= 4'd0;
                            swap_flag <= 1'b0;
                        end
                    end
                end
                
                SORTING: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Bubble sort pass for entrance array
                    // Compare adjacent elements and swap if needed
                    // Only compare within valid range (num_trucks)
                    if (sort_idx < num_trucks - 4'd1) begin
                        // Compare sorted_entrance[sort_idx] and sorted_entrance[sort_idx+1]
                        if (sorted_entrance[sort_idx] > sorted_entrance[sort_idx + 1]) begin
                            // Swap entrance values
                            temp_swap <= sorted_entrance[sort_idx];
                            sorted_entrance[sort_idx] <= sorted_entrance[sort_idx + 1];
                            sorted_entrance[sort_idx + 1] <= temp_swap;
                            swap_flag <= 1'b1;
                        end
                        
                        // Compare and swap exit values in the same positions
                        if (sorted_exit[sort_idx] > sorted_exit[sort_idx + 1]) begin
                            temp_swap <= sorted_exit[sort_idx];
                            sorted_exit[sort_idx] <= sorted_exit[sort_idx + 1];
                            sorted_exit[sort_idx + 1] <= temp_swap;
                            swap_flag <= 1'b1;
                        end
                        
                        sort_idx <= sort_idx + 4'd1;
                    end else begin
                        // End of pass, check if more passes needed
                        if (cycle_counter >= num_trucks - 4'd1) begin
                            // All sorting passes complete
                            state <= COMPUTING;
                            compute_idx <= 4'd0;
                            accumulator <= 32'd0;
                            cycle_counter <= 4'd0;
                        end else begin
                            // Start next pass
                            sort_idx <= 4'd0;
                            cycle_counter <= cycle_counter + 4'd1;
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= COMPUTING;
                        compute_idx <= 4'd0;
                        accumulator <= 32'd0;
                    end
                end
                
                COMPUTING: begin
                    // Compute sum of absolute differences
                    // Use accumulator to accumulate results
                    if (compute_idx < num_trucks) begin
                        // Compute |sorted_entrance[compute_idx] - sorted_exit[compute_idx]|
                        // Since both are sorted, entrance should be <= exit for minimal sum
                        // But we compute absolute difference to be safe
                        if (sorted_entrance[compute_idx] > sorted_exit[compute_idx]) begin
                            accumulator <= accumulator + (sorted_entrance[compute_idx] - sorted_exit[compute_idx]);
                        end else begin
                            accumulator <= accumulator + (sorted_exit[compute_idx] - sorted_entrance[compute_idx]);
                        end
                        compute_idx <= compute_idx + 4'd1;
                    end else begin
                        // Computation complete
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator;
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (num_trucks == 4'd0) begin
                        next_state = FINISH;
                    end else begin
                        next_state = SORTING;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            SORTING: begin
                // Continue until sorting complete
                // Transition to COMPUTING handled inside sequential block
                next_state = SORTING;
            end
            
            COMPUTING: begin
                // Continue until computation complete
                // Transition to FINISH handled inside sequential block
                next_state = COMPUTING;
            end
            
            FINISH: begin
                // Done pulse is set, next state is IDLE
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule