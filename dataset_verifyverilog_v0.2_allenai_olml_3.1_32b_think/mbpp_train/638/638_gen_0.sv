module wind_chill(
    input clk,
    input rst_n,
    input start,
    input [15:0] v,
    input [15:0] t,
    output reg [15:0] result,
    output reg done
);

parameter INT_13_12 = 32'h000D1F48;
parameter FRAC_0_6215 = 32'h00009EB8;
parameter INT_11_37 = 32'h000B5E64;
parameter FRAC_0_3965 = 32'h0000659F;

reg [31:0] lut_val;
always @(*) begin
    lut_val = 32'd0;
    case (v)
        0: lut_val = 32'd0;
        1: lut_val = 32'd65536;
        default: lut_val = 32'd0;
    endcase
end

reg [2:0] state;
reg [1:0] cycle_count;
reg [1:0] cycle_count_done;
reg [31:0] term1, term2, term3, temp_t, total;
reg [15:0] rounded_result;

wire [31:0] t_32 = {16'd0, t};

always @(posedge clk) begin
    if (!rst_n) begin
        state <= 3'd0;
        cycle_count <= 2'd0;
        cycle_count_done <= 2'd0;
        result <= 16'd0;
        done <= 1'b0;
        term1 <= 32'd0;
        term2 <= 32'd0;
        term3 <= 32'd0;
        temp_t <= 32'd0;
        total <= 32'd0;
        rounded_result <= 16'd0;
    end else begin
        if (state == 3'd0) begin // IDLE
            if (start) begin
                state <= 3'd1;
                cycle_count <= 2'd2;
            end
            done <= 1'b0;
            result <= 16'd0;
        end else if (state == 3'd1) begin // CALC1
            term1 = (FRAC_0_6215 * t_32) >> 16;
            if (cycle_count == 2'd0) begin
                state <= 3'd2;
                cycle_count <= 2'd2;
            end else begin
                cycle_count <= cycle_count - 1;
            end
            done <= 1'b0;
            result <= 16'd0;
        end else if (state == 3'd2) begin // CALC2
            temp_t = (FRAC_0_3965 * t_32) >> 16;
            term3 = (temp_t * lut_val) >> 16;
            term2 = (INT_11_37 * lut_val) >> 16;
            if (cycle_count == 2'd0) begin
                state <= 3'd3;
                cycle_count <= 2'd2;
            end else begin
                cycle_count <= cycle_count - 1;
            end
            done <= 1'b0;
            result <= 16'd0;
        end else if (state == 3'd3) begin // CALC3
            total = INT_13_12 + term1 - term2 + term3;
            if (cycle_count == 2'd0) begin
                state <= 3'd4;
                cycle_count <= 2'd2;
            end else begin
                cycle_count <= cycle_count - 1;
            end
            done <= 1'b0;
            result <= 16'd0;
        end else if (state == 3'd4) begin // CALC4
            rounded_result = (total + 32'd32768) >> 16;
            if (cycle_count == 2'd0) begin
                state <= 3'd5;
                cycle_count_done <= 2'd1;
            end else begin
                cycle_count <= cycle_count - 1;
            end
            done <= 1'b0;
            result <= 16'd0;
        end else if (state == 3'd5) begin // DONE
            if (cycle_count_done == 2'd0) begin
                result <= rounded_result;
                done <= 1'b1;
            end else begin
                cycle_count_done <= cycle_count_done - 1;
            end
        end
    end
end

endmodule