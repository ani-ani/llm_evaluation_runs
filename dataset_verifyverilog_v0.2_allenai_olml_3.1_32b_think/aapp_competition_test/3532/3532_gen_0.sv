module string_explosion (
    input clk,
    input rst_n,
    input start,
    input [7:0] str_in [0:15],
    input [7:0] exp_in [0:7],
    input [5:0] str_len,
    input [5:0] exp_len,
    output reg [7:0] result [0:15],
    output reg [5:0] result_len,
    output reg done,
    output reg empty
);

// Internal registers
reg [7:0] stack [0:15];
reg [3:0] stack_ptr;
reg [5:0] input_index;
reg [2:0] state;
reg [5:0] current_len;
reg [2:0] chain_iter;

// States
localparam IDLE = 3'b000;
localparam INIT_LOAD = 3'b001;
localparam PROCESS_INPUT = 3'b010;
localparam CHECK_EXPLOSION = 3'b011;
localparam EXPLODE = 3'b100;
localparam RECHECK = 3'b101;
localparam CHAINREACTION = 3'b110;
localparam DONE = 3'b111;

// Outputs
assign result = stack[0:current_len-1];
assign result_len = current_len;
assign empty = (current_len == 0);
assign done = (state == DONE);

always @(posedge clk) begin
    if (!rst_n) begin
        stack <= 16'b0;
        stack_ptr <= 4'b0;
        input_index <= 6'b0;
        current_len <= 6'b0;
        state <= IDLE;
        chain_iter <= 6'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start) state <= INIT_LOAD;
            end
            INIT_LOAD: begin
                state <= PROCESS_INPUT;
                input_index <= 0;
                stack_ptr <= 4'b0;
                current_len <= 4'b0;
            end
            PROCESS_INPUT: begin
                if (input_index < str_len) begin
                    stack[stack_ptr] <= str_in[input_index];
                    stack_ptr <= stack_ptr + 1;
                    current_len <= stack_ptr;
                    input_index <= input_index + 1;
                    if (exp_len > 0 && stack_ptr >= exp_len) begin
                        bit match;
                        match = 1'b1;
                        if (exp_len == 1) match = (stack[stack_ptr-1] == exp_in[0]);
                        else if (exp_len == 2) match = (stack[stack_ptr-2] == exp_in[0] && stack[stack_ptr-1] == exp_in[1]);
                        if (match) begin
                            state <= EXPLODE;
                        end else begin
                            state <= PROCESS_INPUT;
                        end
                    end else begin
                        state <= PROCESS_INPUT;
                    end
                end else begin
                    state <= DONE;
                end
            end
            EXPLODE: begin
                stack_ptr <= stack_ptr - exp_len;
                current_len <= stack_ptr;
                state <= RECHECK;
            end
            RECHECK: begin
                if (exp_len > 0 && stack_ptr >= exp_len) begin
                    bit match;
                    match = 1'b1;
                    if (exp_len == 1) match = (stack[stack_ptr-1] == exp_in[0]);
                    else if (exp_len == 2) match = (stack[stack_ptr-2] == exp_in[0] && stack[stack_ptr-1] == exp_in[1]);
                    if (match) begin
                        state <= EXPLODE;
                    end else begin
                        state <= DONE;
                    end
                end else begin
                    state <= DONE;
                end
            end
            DONE: begin
                // Stay in DONE
            end
        endcase
    end
end

endmodule