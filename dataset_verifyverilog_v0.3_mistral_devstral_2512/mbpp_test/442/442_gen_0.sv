module positive_ratio(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] CALCULATING = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] pos_count;
    reg [15:0] numerator;
    reg [15:0] quotient;
    reg [5:0] bit_idx;

    // Combinational logic for array element access
    wire [7:0] current_elem;
    assign current_elem = (idx == 4'd0) ? arr_0 :
                          (idx == 4'd1) ? arr_1 :
                          (idx == 4'd2) ? arr_2 :
                          (idx == 4'd3) ? arr_3 :
                          (idx == 4'd4) ? arr_4 :
                          (idx == 4'd5) ? arr_5 :
                          (idx == 4'd6) ? arr_6 :
                          arr_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            pos_count <= 4'd0;
            result <= 16'd0;
            done <= 1'b0;
            numerator <= 16'd0;
            quotient <= 16'd0;
            bit_idx <= 6'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COUNTING;
                        idx <= 4'd0;
                        pos_count <= 4'd0;
                    end
                end

                COUNTING: begin
                    if (idx < len) begin
                        if (current_elem[7] == 1'b0 && current_elem != 8'd0) begin
                            pos_count <= pos_count + 1'b1;
                        end
                        idx <= idx + 1'b1;
                    end else begin
                        state <= CALCULATING;
                        numerator <= {8'd0, pos_count} << 8;
                        quotient <= 16'd0;
                        bit_idx <= 6'd16;
                    end
                end

                CALCULATING: begin
                    if (bit_idx > 0) begin
                        quotient <= quotient << 1;
                        if (numerator[15:8] >= {1'b0, len}) begin
                            quotient[0] <= 1'b1;
                            numerator[15:8] <= numerator[15:8] - {1'b0, len};
                        end
                        numerator <= numerator << 1;
                        bit_idx <= bit_idx - 1'b1;
                    end else begin
                        state <= DONE_STATE;
                        result <= quotient;
                        done <= 1'b1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule