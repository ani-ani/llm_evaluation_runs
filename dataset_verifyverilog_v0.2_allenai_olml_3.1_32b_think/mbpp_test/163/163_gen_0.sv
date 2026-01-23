module polygon_area(input clk, input rst_n, input start, input [15:0] s, input [31:0] l, output reg [31:0] result, output reg done);

// Lookup table for tan(π/s) in Q16.16
localparam tan_lut [10] = {32'h0001BB67, 32'h00010000, 32'h0000B9EF, 32'h000093D7, 32'h00007B63, 32'h00006A28, 32'h00005CC4, 32'h00005337, 32'h00004B5E, 32'h0000449D};

reg [2:0] state;
reg [15:0] s_reg;
reg [31:0] l_reg;
reg [31:0] l_sq;
reg [31:0] tan_val;
reg [31:0] a;
reg [31:0] b;
reg [31:0] quotient;
reg [7:0] count;

// State definitions
localparam IDLE = 3'd0, CALC_LSQ = 3'd1, CALC_TAN = 3'd2, CALC_DIV = 3'd3, DONE = 3'd4;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        s_reg <= 16'd0;
        l_reg <= 32'd0;
        l_sq <= 32'd0;
        tan_val <= 32'd0;
        a <= 32'd0;
        b <= 32'd0;
        quotient <= 32'd0;
        count <= 8'd0;
        result <= 32'd0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                if (start)
                    s_reg <= s;
                    l_reg <= l;
                    state <= CALC_LSQ;
                done <= 1'b0;
                result <= 32'd0;
            end
            CALC_LSQ: begin
                l_sq <= l_reg * l_reg >> 16;
                state <= CALC_TAN;
                done <= 1'b0;
                result <= 32'd0;
            end
            CALC_TAN: begin
                tan_val <= tan_lut[s_reg - 3];
                state <= CALC_DIV;
                done <= 1'b0;
                result <= 32'd0;
            end
            CALC_DIV: begin
                if (state == CALC_DIV) begin
                    b <= tan_val << 2;
                    a <= ({s_reg << 16}) [31:0] * l_sq >> 16;
                    quotient <= 32'd0;
                    count <= 8'd0;
                end
                if (count < 100) begin
                    if (a >= b) begin
                        a <= a - b;
                        quotient <= quotient + 1;
                    end
                    count <= count + 1;
                    if (a < b || count == 100) begin
                        state <= DONE;
                        result <= quotient;
                        done <= 1'b1;
                    end else begin
                        state <= CALC_DIV;
                    end
                end else begin
                    state <= DONE;
                    result <= quotient;
                    done <= 1'b1;
                end
            end
            DONE: begin
                if (!start)
                    state <= IDLE;
            end
        endcase
    end
endmodule