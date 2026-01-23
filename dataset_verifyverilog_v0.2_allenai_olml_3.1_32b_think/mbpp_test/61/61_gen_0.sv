module count_substrings (
    output reg [7:0] result,
    output reg done,
    input clk,
    input rst_n,
    input start,
    input [127:0] s,
    input [4:0] len
);

localparam IDLE = 3'd0, PROCESSING = 3'd2, DONE = 3'd3;

reg [2:0] state;
reg [4:0] reg_len;
reg [15:0] prefix_sum;
reg [7:0] result_reg;
reg [2:0] current_index;
reg [3:0] table [32:0];

wire [7:0] char_byte;
wire [31:0] wire_current_val;
wire [3:0] count;
wire [4:0] table_index;

assign char_byte = s[(current_index * 8) + 7 : current_index * 8];
assign wire_current_val = prefix_sum - current_index;
assign table_index = wire_current_val + 16;

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        reg_len <= 5'd0;
        prefix_sum <= 16'd0;
        result_reg <= 8'd0;
        current_index <= 3'd0;
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= PROCESSING;
                    reg_len <= len;
                end
            end
            PROCESSING: begin
                if (current_index < reg_len) begin
                    prefix_sum <= prefix_sum + (char_byte - 8'h30);
                    result_reg <= result_reg + table[table_index];
                    table[table_index] <= table[table_index] + 1;
                    current_index <= current_index + 1;
                end else begin
                    state <= DONE;
                    done <= 1'b1;
                end
            end
            DONE: begin
                done <= 1'b1;
            end
            default: state <= IDLE;
        endcase
    end
end
endmodule