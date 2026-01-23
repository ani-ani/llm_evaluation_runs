module remove_uppercase (
    input clk,
    input rst_n,   // Active-low reset
    input start,
    input [127:0] str_in,
    output reg [127:0] str_out,
    output reg done
);

localparam IDLE = 2'd0;
localparam PROCESS = 2'd1;
localparam DONE_STATE = 2'd2;

reg [1:0] state;
reg [4:0] input_index;
reg [4:0] output_index;
reg [127:0] str_out;
reg done_reg;

always_ff @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        input_index <= 0;
        output_index <= 0;
        str_out <= 0;
        done_reg <= 0;
    end else begin
        case(state)
            IDLE: begin
                if (start) begin
                    state <= PROCESS;
                    input_index <= 0;
                    output_index <= 0;
                    str_out <= 0;
                    done_reg <= 0;
                end else begin
                    state <= IDLE;
                end
            end
            PROCESS: begin
                integer char_val;
                char_val = (str_in >> (input_index * 8)) & 8'hFF;
                integer write_mask;
                write_mask = (8'hFF << (output_index * 8));
                integer new_output_index;
                integer new_str_out;
                new_str_out = str_out;
                new_output_index = output_index;

                if (char_val >= 'A' && char_val <= 'Z') begin
                    // Do nothing
                end else begin
                    new_str_out = str_out & ~write_mask | (char_val << (output_index * 8));
                    new_output_index = output_index + 1;
                end

                str_out <= new_str_out;
                output_index <= new_output_index;
                input_index <= input_index + 1;

                if (input_index == 16) begin
                    state <= DONE_STATE;
                end else begin
                    state <= PROCESS;
                end
                done_reg <= 0;
            end
            DONE_STATE: begin
                done_reg <= 1;
                state <= IDLE;
                input_index <= 0;
                output_index <= 0;
                str_out <= 0;
            end
        endcase
    end
end

assign done = done_reg;

endmodule