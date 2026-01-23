module check_reverse (
    input clk,
    input rst_n,  // active low
    input start,
    input [7:0] n,
    output reg result,
    output reg done
);

// Internal registers
reg [2:0] state, state_next;
reg [7:0] input_n, input_n_next;
reg [15:0] reverse_num, reverse_num_next;
reg [7:0] remaining, remaining_next;
reg [15:0] temp1, temp1_next;
reg [15:0] temp2, temp2_next;
reg result_reg, result_reg_next;
reg done_reg, done_reg_next;

// State definitions
localparam IDLE = 3'd0;
localparam REVERSE_LOOP = 3'd1;
localparam CALCULATE = 3'd2;
localparam COMPARE = 3'd3;
localparam DONE = 3'd4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Reset all registers
        state <= IDLE;
        input_n <= 8'b0;
        reverse_num <= 16'b0;
        remaining <= 8'b0;
        temp1 <= 16'b0;
        temp2 <= 16'b0;
        result_reg <= 1'b0;
        done_reg <= 1'b0;
    end else begin
        // Default assignments for next registers
        state_next <= state;
        input_n_next <= input_n;
        reverse_num_next <= reverse_num;
        remaining_next <= remaining;
        temp1_next <= temp1;
        temp2_next <= temp2;
        result_reg_next <= result_reg;
        done_reg_next <= done_reg;

        case(state)
            IDLE: begin
                if (start) begin
                    state_next <= REVERSE_LOOP;
                    input_n_next <= n;
                    reverse_num_next <= 16'b0;
                    remaining_next <= n; // Use n directly
                end
            end
            REVERSE_LOOP: begin
                if (remaining == 0) begin
                    state_next <= CALCULATE;
                end else begin
                    reverse_num_next = reverse_num * 10 + (remaining % 10);
                    remaining_next = remaining / 10;
                    state_next <= REVERSE_LOOP;
                end
            end
            CALCULATE: begin
                temp1_next = reverse_num * 2;
                temp2_next = input_n + 1;
                state_next <= COMPARE;
            end
            COMPARE: begin
                result_reg_next = (temp1 == temp2) ? 1'b1 : 1'b0;
                state_next <= DONE;
            end
            DONE: begin
                done_reg_next <= 1'b1;
                state_next <= DONE;
            end
        endcase
    end
end

// Output assignments
assign done = done_reg;
assign result = done_reg ? result_reg : 1'b0;

endmodule