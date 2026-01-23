module permutation_generator(
    input clk,
    input rst_n,
    input start,
    input [9:0] N,
    input [5:0] A,
    input [5:0] B,
    output reg [9:0] data_out,
    output reg valid_out,
    output reg done
);

    // State Encoding
    localparam IDLE = 2'b00;
    localparam CALCULATE = 2'b01;
    localparam OUTPUT = 2'b10;
    localparam FINISH = 2'b11;

    reg [1:0] state, next_state;
    
    // Internal Registers
    reg [9:0] rem_reg;
    reg [9:0] base_reg;
    reg [5:0] rem_count_reg;
    reg [5:0] group_idx;
    reg [9:0] current_val;
    reg [9:0] count_out;
    reg is_decreasing_block; // 1 for decreasing blocks, 0 for increasing tail
    reg [9:0] block_size;
    reg [9:0] current_max_val; // Track highest value for decreasing blocks

    // Control Signals
    wire is_last_group = (group_idx == B - 1);
    wire is_tail = is_last_group;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            // Reset outputs
            data_out <= 0;
            valid_out <= 0;
            done <= 0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    done <= 0;
                    if (start) begin
                        // Initialize for calculation
                        group_idx <= 0;
                        // Handle B=1 case: All numbers are the tail (1..A=N)
                        if (B <= 1) begin
                            rem_reg <= 0;
                            base_reg <= 0;
                            rem_count_reg <= 0;
                        end else begin
                            rem_reg <= N - A;
                            base_reg <= (N - A) / (B - 1);
                            rem_count_reg <= (N - A) % (B - 1);
                        end
                    end
                end

                CALCULATE: begin
                    // Determine block size and starting value for the current group
                    if (is_last_group || B <= 1) begin
                        // Last group: Tail (1 to A)
                        block_size <= A;
                        is_decreasing_block <= 0;
                        current_val <= 1;
                    end else begin
                        // Middle/First groups: Decreasing blocks
                        if (group_idx < rem_count_reg) begin
                            block_size <= base_reg + 1;
                        end else begin
                            block_size <= base_reg;
                        end
                        is_decreasing_block <= 1;
                        // Calculate start value for decreasing block
                        // Values: current_max_val down to current_max_val - block_size + 1
                        if (group_idx == 0) begin
                            current_max_val <= N;
                        end else begin
                            // If previous group used extra size
                            if ((group_idx - 1) < rem_count_reg) begin
                                current_max_val <= current_max_val - (base_reg + 1);
                            end else begin
                                current_max_val <= current_max_val - base_reg;
                            end
                        end
                    end
                    count_out <= 0;
                end

                OUTPUT: begin
                    if (count_out < block_size) begin
                        valid_out <= 1;
                        count_out <= count_out + 1;
                        
                        if (is_decreasing_block) begin
                            // Output decreasing sequence from current_max_val
                            data_out <= current_max_val - count_out;
                        end else begin
                            // Output increasing sequence from current_val
                            data_out <= current_val + count_out;
                        end
                    end else begin
                        valid_out <= 0;
                        // Finished current block
                        if (is_last_group || B <= 1) begin
                            // Done with all groups
                            done <= 1;
                        end else begin
                            // Move to next group
                            group_idx <= group_idx + 1;
                            // Update current_max_val for next block calculation
                            if (group_idx < rem_count_reg) begin
                                current_max_val <= current_max_val - (base_reg + 1);
                            end else begin
                                current_max_val <= current_max_val - base_reg;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1;
                    valid_out <= 0;
                end
            endcase
        end
    end

    // Next State Logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: if (start) next_state = CALCULATE;
            
            CALCULATE: next_state = OUTPUT;
            
            OUTPUT: begin
                if (count_out < block_size) begin
                    next_state = OUTPUT; // Stay to output next value
                end else begin
                    if (is_last_group || B <= 1) next_state = FINISH;
                    else next_state = CALCULATE; // Next group
                end
            end
            
            FINISH: begin
                if (!start) next_state = IDLE; // Wait for reset/start to go low
            end
        endcase
    end

endmodule