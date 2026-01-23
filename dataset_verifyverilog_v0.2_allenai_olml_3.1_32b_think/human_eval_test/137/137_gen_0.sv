module compare_one (
    input clk,
    input rst_n,
    input start,
    input [1:0] type_a,
    input [1:0] type_b,
    input [31:0] data_a,
    input [31:0] data_b,
    output reg [1:0] result_type,
    output reg [31:0] result_data,
    output reg done
);

reg [2:0] state;
reg [31:0] q16_a, q16_b;
reg [1:0] orig_type_a, orig_type_b;
reg [1:0] res_type;
reg [31:0] res_data;
reg done_reg;

localparam IDLE = 3'd0, PARSE_A=3'd1, PARSE_B=3'd2, COMPARE=3'd3, DONE=3'd4;

function [31:0] convert_to_q16;
    input [1:0] type,
    input [31:0] data;
    case(type)
        2'd0: return data << 16;
        2'd1: return data;
        2'd2: return data << 16;
    endcase
endfunction

function [31:0] convert_to_original;
    input [1:0] type,
    input [31:0] q16_val;
    case(type)
        2'd0: return q16_val >> 16;
        2'd1: return q16_val;
        2'd2: return q16_val >> 16;
    endcase
endfunction

always @(posedge clk) begin
    if (!rst_n) begin
        state <= IDLE;
        q16_a <= 32'd0;
        q16_b <= 32'd0;
        orig_type_a <= 2'd0;
        orig_type_b <= 2'd0;
        res_type <= 2'd0;
        res_data <= 32'd0;
        done_reg <= 1'b0;
    end else begin
        case(state)
            IDLE: begin
                if (start) state <= PARSE_A;
                else state <= IDLE;
            end
            PARSE_A: begin
                orig_type_a <= type_a;
                q16_a <= convert_to_q16(type_a, data_a);
                state <= PARSE_B;
            end
            PARSE_B: begin
                orig_type_b <= type_b;
                q16_b <= convert_to_q16(type_b, data_b);
                state <= COMPARE;
            end
            COMPARE: begin
                if (q16_a > q16_b) begin
                    res_type <= orig_type_a;
                    res_data <= convert_to_original(orig_type_a, q16_a);
                end else if (q16_a < q16_b) begin
                    res_type <= orig_type_b;
                    res_data <= convert_to_original(orig_type_b, q16_b);
                end else begin
                    res_type <= 2'd11;
                    res_data <= 32'd0;
                end
                state <= DONE;
            end
            DONE: done_reg <= 1'b1;
        endcase
    end
end

assign result_type = res_type;
assign result_data = res_data;
assign done = done_reg;

endmodule