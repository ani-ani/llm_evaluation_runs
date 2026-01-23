module count_ones_range (
    input clk,
    input rst_n,
    input start,
    input [15:0] n_in,
    input [13:0] l_in,
    input [13:0] r_in,
    output reg [31:0] result,
    output reg done
);

// Internal signals
reg [2:0] state;
localparam IDLE = 3'd0, CALCULATE_LEN = 3'd1, PUSH_CALL=3'd2, POP_AND_PROCESS=3'd3, UPDATE_RESULT=3'd4, DONE=3'd5;

reg [15:0] stack_x [15:0];
reg [13:0] stack_start [15:0], stack_end [15:0];
reg [3:0] stack_ptr;

reg [15:0] current_x;
reg [13:0] current_start, current_end;

reg [31:0] result_reg;
reg done_reg;

function int compute_len(int x);
    int len;
    if (x <= 1) begin
        len = 1;
    end else begin
        len = 1;
        int temp = x;
        for (int i=0; i<16; i++) begin
            if (temp <= 1) break;
            temp = temp >> 1;
            len = 2 * len + 1;
        end
    end
    return len;
endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        stack_ptr <= 4'd0;
        result_reg <= 32'd0;
        done_reg <= 1'b0;
        current_x <= 16'd0;
        current_start <= 14'd0;
        current_end <= 14'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= CALCULATE_LEN;
                    current_x <= n_in;
                    current_start <= 14'd1;
                end
            end
            CALCULATE_LEN: begin
                current_end <= compute_len(current_x) + current_start - 1;
                if (current_x <= 1) begin
                    // Leaf node, check and update
                    if (current_start <= r_in && current_end >= l_in) begin
                        if (current_start == current_end && current_start >= l_in && current_start <= r_in) begin
                            result_reg <= result_reg + current_x;
                        end
                    end
                    state <= DONE;
                end else begin
                    state <= PUSH_CALL;
                end
            end
            PUSH_CALL: begin
                int len_left = compute_len(current_x >> 1);
                int mid = current_start + len_left;
                // Push right part if overlaps
                if (mid + 1 <= current_end && mid + 1 <= r_in && mid + 1 >= l_in) begin
                    if (stack_ptr < 15) begin
                        stack_ptr <= stack_ptr + 1;
                        stack_x[stack_ptr-1] <= current_x >> 1;
                        stack_start[stack_ptr-1] <= mid + 1;
                        stack_end[stack_ptr-1] <= current_end;
                    end
                end
                // Push middle if overlaps
                if (mid >= l_in && mid <= r_in) begin
                    if (stack_ptr < 15) begin
                        stack_ptr <= stack_ptr + 1;
                        stack_x[stack_ptr-1] <= current_x % 2;
                        stack_start[stack_ptr-1] <= mid;
                        stack_end[stack_ptr-1] <= mid;
                    end
                end
                // Push left part if overlaps
                if (current_start <= mid - 1 && mid - 1 >= l_in) begin
                    if (stack_ptr < 15) begin
                        stack_ptr <= stack_ptr + 1;
                        stack_x[stack_ptr-1] <= current_x >> 1;
                        stack_start[stack_ptr-1] <= current_start;
                        stack_end[stack_ptr-1] <= mid - 1;
                    end
                end
                state <= POP_AND_PROCESS;
            end
            POP_AND_PROCESS: begin
                if (stack_ptr == 0) begin
                    done_reg <= 1'b1;
                    state <= DONE;
                end else begin
                    current_x <= stack_x[stack_ptr-1];
                    current_start <= stack_start[stack_ptr-1];
                    current_end <= stack_end[stack_ptr-1];
                    stack_ptr <= stack_ptr - 1;
                    if (current_x <= 1) begin
                        if (current_start >= l_in && current_start <= r_in) begin
                            result_reg <= result_reg + current_x;
                        end
                        state <= POP_AND_PROCESS;
                    end else begin
                        state <= CALCULATE_LEN;
                    end
                end
            end
            UPDATE_RESULT: begin
                state <= POP_AND_PROCESS;
            end
            DONE: begin
                done_reg <= 1'b1;
            end
        endcase
        result <= result_reg;
        done <= done_reg;
    end
endmodule