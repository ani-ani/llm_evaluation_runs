module zebra_partitioner(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire char_in,
    input wire char_valid,
    input wire read_done,
    output reg ready,
    output reg done,
    output reg error,
    output reg [7:0] k_out,
    output reg [3:0] li_out,
    output reg [15:0] idx_out,
    output reg idx_valid,
    output reg subseq_done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT_PHASE = 3'd1;
    localparam [2:0] VALIDATION_PHASE = 3'd2;
    localparam [2:0] OUTPUT_K = 3'd3;
    localparam [2:0] OUTPUT_LI = 3'd4;
    localparam [2:0] OUTPUT_IDX = 3'd5;
    localparam [2:0] DONE_STATE = 3'd6;
    localparam [2:0] ERROR_STATE = 3'd7;

    reg [2:0] state, next_state;

    // Storage for subsequences
    reg [15:0] buffer [0:65535];
    reg [15:0] buffer_ptr;
    reg [7:0] k;

    // Stacks for tracking subsequences ending in 0 and 1
    reg [15:0] stack_0 [0:255];
    reg [15:0] stack_1 [0:255];
    reg [7:0] stack_0_ptr;
    reg [7:0] stack_1_ptr;

    // Current subsequence tracking
    reg [15:0] current_subseq_start;
    reg [15:0] current_subseq_end;

    // Output phase tracking
    reg [7:0] output_subseq_idx;
    reg [15:0] output_idx_ptr;
    reg [3:0] output_li_counter;

    // Error flag
    reg error_flag;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            buffer_ptr <= 16'd0;
            k <= 8'd0;
            stack_0_ptr <= 8'd0;
            stack_1_ptr <= 8'd0;
            current_subseq_start <= 16'd0;
            current_subseq_end <= 16'd0;
            output_subseq_idx <= 8'd0;
            output_idx_ptr <= 16'd0;
            output_li_counter <= 4'd0;
            error_flag <= 1'b0;
            ready <= 1'b1;
            done <= 1'b0;
            error <= 1'b0;
            k_out <= 8'd0;
            li_out <= 4'd0;
            idx_out <= 16'd0;
            idx_valid <= 1'b0;
            subseq_done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // State machine logic
    always @(posedge clk) begin
        case (state)
            IDLE: begin
                ready <= 1'b1;
                done <= 1'b0;
                error <= 1'b0;
                if (start && char_valid) begin
                    if (char_in == 1'b1) begin
                        error_flag <= 1'b1;
                        next_state <= ERROR_STATE;
                    end else begin
                        // Start new subsequence
                        k <= k + 8'd1;
                        stack_0_ptr <= stack_0_ptr + 8'd1;
                        stack_0[stack_0_ptr] <= 16'd1;
                        buffer[buffer_ptr] <= 16'd1;
                        buffer_ptr <= buffer_ptr + 16'd1;
                        current_subseq_start <= 16'd1;
                        current_subseq_end <= 16'd1;
                        next_state <= INPUT_PHASE;
                    end
                end
            end

            INPUT_PHASE: begin
                ready <= 1'b1;
                if (char_valid) begin
                    if (char_in == 1'b0) begin
                        // Must extend a subsequence ending in 1 or start new
                        if (stack_1_ptr > 8'd0) begin
                            // Extend existing subsequence ending in 1
                            stack_1_ptr <= stack_1_ptr - 8'd1;
                            current_subseq_end <= stack_1[stack_1_ptr];
                            buffer[buffer_ptr] <= current_subseq_end + 16'd1;
                            buffer_ptr <= buffer_ptr + 16'd1;
                            stack_0_ptr <= stack_0_ptr + 8'd1;
                            stack_0[stack_0_ptr] <= current_subseq_end + 16'd1;
                        end else begin
                            // Start new subsequence
                            k <= k + 8'd1;
                            stack_0_ptr <= stack_0_ptr + 8'd1;
                            stack_0[stack_0_ptr] <= current_subseq_end + 16'd1;
                            buffer[buffer_ptr] <= current_subseq_end + 16'd1;
                            buffer_ptr <= buffer_ptr + 16'd1;
                        end
                    end else begin
                        // char_in == 1'b1
                        // Must extend a subsequence ending in 0
                        if (stack_0_ptr > 8'd0) begin
                            stack_0_ptr <= stack_0_ptr - 8'd1;
                            current_subseq_end <= stack_0[stack_0_ptr];
                            buffer[buffer_ptr] <= current_subseq_end + 16'd1;
                            buffer_ptr <= buffer_ptr + 16'd1;
                            stack_1_ptr <= stack_1_ptr + 8'd1;
                            stack_1[stack_1_ptr] <= current_subseq_end + 16'd1;
                        end else begin
                            error_flag <= 1'b1;
                            next_state <= ERROR_STATE;
                        end
                    end
                end else if (read_done) begin
                    next_state <= VALIDATION_PHASE;
                end
            end

            VALIDATION_PHASE: begin
                ready <= 1'b0;
                if (stack_1_ptr > 8'd0) begin
                    error_flag <= 1'b1;
                    next_state <= ERROR_STATE;
                end else begin
                    next_state <= OUTPUT_K;
                end
            end

            OUTPUT_K: begin
                ready <= 1'b0;
                k_out <= k;
                next_state <= OUTPUT_LI;
            end

            OUTPUT_LI: begin
                ready <= 1'b0;
                if (output_subseq_idx < k) begin
                    // Calculate length of current subsequence
                    reg [15:0] start_idx;
                    reg [15:0] end_idx;
                    reg [3:0] length;
                    
                    // Find start and end of current subsequence
                    if (output_subseq_idx == 8'd0) begin
                        start_idx <= 16'd1;
                        end_idx <= buffer[0];
                    end else begin
                        start_idx <= buffer[output_subseq_idx - 8'd1] + 16'd1;
                        end_idx <= buffer[output_subseq_idx];
                    end
                    
                    length <= end_idx - start_idx + 16'd1;
                    li_out <= length;
                    output_idx_ptr <= start_idx;
                    output_li_counter <= length;
                    next_state <= OUTPUT_IDX;
                end else begin
                    next_state <= DONE_STATE;
                end
            end

            OUTPUT_IDX: begin
                ready <= 1'b0;
                idx_out <= output_idx_ptr;
                idx_valid <= 1'b1;
                output_li_counter <= output_li_counter - 4'd1;
                output_idx_ptr <= output_idx_ptr + 16'd1;
                
                if (output_li_counter == 4'd1) begin
                    subseq_done <= 1'b1;
                    output_subseq_idx <= output_subseq_idx + 8'd1;
                    next_state <= OUTPUT_LI;
                end else begin
                    subseq_done <= 1'b0;
                end
            end

            DONE_STATE: begin
                ready <= 1'b1;
                done <= 1'b1;
                next_state <= IDLE;
            end

            ERROR_STATE: begin
                ready <= 1'b1;
                error <= 1'b1;
                next_state <= IDLE;
            end

            default: begin
                next_state <= IDLE;
            end
        endcase
    end

endmodule