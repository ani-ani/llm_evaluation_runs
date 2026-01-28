module generate_permutation (
    input clk,
    input rst_n,
    input start,
    input [23:0] N,
    input [19:0] K,
    output reg [15:0] data,
    output reg valid,
    output reg done,
    output reg error
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CHECK = 3'd1;
    localparam [2:0] CALC_BLOCK = 3'd2;
    localparam [2:0] OUTPUT_BLOCK = 3'd3;
    localparam [2:0] FINISH = 3'd4;
    localparam [2:0] ERROR_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [23:0] current_N;
    reg [19:0] current_K;
    reg [23:0] block_size;
    reg [23:0] num_blocks;
    reg [23:0] current_block;
    reg [23:0] block_start;
    reg [23:0] block_end;
    reg [23:0] current_num;
    reg [23:0] output_count;
    reg [23:0] max_outputs;
    
    // Fixed width constants
    localparam [23:0] MAX_N = 24'd1000000;
    localparam [19:0] MAX_K = 20'd1000000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            data <= 16'd0;
            valid <= 1'b0;
            done <= 1'b0;
            error <= 1'b0;
            current_N <= 24'd0;
            current_K <= 20'd0;
            block_size <= 24'd0;
            num_blocks <= 24'd0;
            current_block <= 24'd0;
            block_start <= 24'd0;
            block_end <= 24'd0;
            current_num <= 24'd0;
            output_count <= 24'd0;
            max_outputs <= 24'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    valid <= 1'b0;
                    data <= 16'd0;
                    output_count <= 24'd0;
                    if (start) begin
                        current_N <= N;
                        current_K <= K;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check for impossible case: K=1 and N>1
                    if ((current_K == 20'd1) && (current_N > 24'd1)) begin
                        state <= ERROR_STATE;
                    end else if (current_K == current_N) begin
                        // Special case: output 1,2,3,...,N
                        state <= OUTPUT_BLOCK;
                        block_start <= 24'd1;
                        block_end <= current_N;
                        current_num <= 24'd1; // Start from 1
                        max_outputs <= current_N;
                    end else begin
                        state <= CALC_BLOCK;
                    end
                end
                
                CALC_BLOCK: begin
                    // Calculate block_size = ceil(N/K) = (N + K - 1) / K
                    // Using integer division
                    block_size <= (current_N + current_K - 24'd1) / current_K;
                    num_blocks <= current_K;
                    current_block <= 24'd0;
                    max_outputs <= current_N;
                    state <= OUTPUT_BLOCK;
                end
                
                OUTPUT_BLOCK: begin
                    if (output_count >= max_outputs) begin
                        state <= FINISH;
                        valid <= 1'b0;
                    end else begin
                        // Determine current block range
                        if (current_K == current_N) begin
                            // Special case: output in increasing order
                            if (current_num <= block_end) begin
                                data <= current_num[15:0];
                                valid <= 1'b1;
                                current_num <= current_num + 24'd1;
                                output_count <= output_count + 24'd1;
                            end else begin
                                valid <= 1'b0;
                            end
                        end else begin
                            // Normal case: blocks in decreasing order
                            // Calculate block range
                            block_start <= current_block * block_size + 24'd1;
                            block_end <= (current_block + 24'd1) * block_size;
                            
                            // Check if this is the last block
                            if (block_end > current_N) begin
                                block_end <= current_N;
                            end
                            
                            // Generate decreasing sequence for this block
                            if (current_num > block_start) begin
                                data <= current_num[15:0];
                                valid <= 1'b1;
                                current_num <= current_num - 24'd1;
                                output_count <= output_count + 24'd1;
                            end else if (current_num == block_start) begin
                                // Last number in block
                                data <= block_start[15:0];
                                valid <= 1'b1;
                                output_count <= output_count + 24'd1;
                                // Move to next block
                                current_block <= current_block + 24'd1;
                                if (current_block + 24'd1 < num_blocks) begin
                                    // Set up for next block (will be done next cycle)
                                    current_num <= ((current_block + 24'd2) * block_size);
                                    // Clamp to N
                                    if (current_num > current_N) begin
                                        current_num <= current_N;
                                    end
                                end
                            end else begin
                                valid <= 1'b0;
                                // Start of new block
                                current_num <= block_end;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                ERROR_STATE: begin
                    error <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Combinational logic to handle block transitions
    always @(*) begin
        if (state == OUTPUT_BLOCK) begin
            if ((current_K != current_N) && (current_num < block_start)) begin
                // Need to set up for next block in next cycle
                // This is handled in sequential logic
            end
        end
    end

endmodule