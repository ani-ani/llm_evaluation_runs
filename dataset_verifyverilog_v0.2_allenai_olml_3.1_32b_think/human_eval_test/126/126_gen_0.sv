module is_sorted (
    input clk,
    input rst_n,
    input start,
    input [2:0] len,
    input [7:0] data_in,
    output reg result,
    output reg done
);

// Next state and next registers for synthesis
reg [7:0] prev_next;
reg [2:0] dup_cnt_next;
reg [2:0] elem_cnt_next;
reg [3:0] cycle_cnt_next;
reg [1:0] error_flag_next;
reg [1:0] state_next;
reg [7:0] result_reg_next;
reg done_reg_next;

// Registers
reg [7:0] prev;
reg [2:0] dup_cnt;
reg [1:0] state;
reg [2:0] elem_cnt;
reg [3:0] cycle_cnt;
reg [1:0] error_flag;
reg [7:0] result_reg;
reg done_reg;

// Start latch
reg start_latched;

// State assignments
localparam IDLE = 2'b00;
localparam PROCESSING = 2'b01;
localparam DONE_STATE = 2'b10;

// Reset
always_ff @(posedge clk) begin
    if (!rst_n) begin
        prev <= 8'b0;
        dup_cnt <= 3'b0;
        state <= IDLE;
        elem_cnt <= 3'b0;
        cycle_cnt <= 4'b0;
        error_flag <= 2'b00;
        result_reg <= 1'b0;
        done_reg <= 1'b0;
        start_latched <= 1'b0;
    end else begin
        if (state == IDLE) begin
            if (start_latched) begin
                state_next <= PROCESSING;
                cycle_cnt_next <= 4'b0;
                elem_cnt_next <= 3'b0;
                prev_next <= 8'b0;
                dup_cnt_next <= 3'b0;
                error_flag_next <= 2'b00;
                result_reg_next <= 1'b1;
                start_latched <= 1'b0;
            end
        end
    end
end

// Processing logic
always_ff @(posedge clk) begin
    prev_next = prev;
    dup_cnt_next = dup_cnt;
    elem_cnt_next = elem_cnt;
    cycle_cnt_next = cycle_cnt;
    error_flag_next = error_flag;
    state_next = state;
    result_reg_next = result_reg;
    done_reg_next = done_reg;

    if (state == PROCESSING) begin
        cycle_cnt_next = cycle_cnt + 1;

        if (cycle_cnt == 4'd8) begin
            state_next <= DONE_STATE;
            done_reg_next <= 1'b1;
            result_reg_next <= (error_flag == 2'b00) ? 1'b1 : 1'b0;
        end else begin
            if (elem_cnt < len) begin
                if (elem_cnt == 0) begin
                    prev_next = data_in;
                    elem_cnt_next = elem_cnt + 1;
                    dup_cnt_next = 3'b1;
                end else begin
                    if (data_in < prev) begin
                        error_flag_next = 2'b01;
                    end else if (data_in == prev) begin
                        dup_cnt_next = dup_cnt + 1;
                        if (dup_cnt_next > 2) begin
                            error_flag_next = 2'b01;
                        end
                    end else begin
                        dup_cnt_next = 3'b1;
                    end
                    prev_next = data_in;
                    elem_cnt_next = elem_cnt + 1;
                end
            end
        end
    end
end

// Output assignments
assign result = result_reg;
assign done = done_reg;

endmodule