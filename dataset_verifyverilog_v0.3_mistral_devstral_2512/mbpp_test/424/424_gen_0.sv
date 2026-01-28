module extract_rear (
    input clk,
    input rst_n,
    input start,
    input [63:0] str_0,
    input [3:0] len_0,
    input [63:0] str_1,
    input [3:0] len_1,
    input [63:0] str_2,
    input [3:0] len_2,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] EXTRACT = 2'd1;
    localparam [1:0] OUTPUT = 2'd2;

    reg [1:0] state;
    reg [7:0] temp_result_0;
    reg [7:0] temp_result_1;
    reg [7:0] temp_result_2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            temp_result_0 <= 8'd0;
            temp_result_1 <= 8'd0;
            temp_result_2 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= EXTRACT;
                    end
                end

                EXTRACT: begin
                    case (len_0)
                        4'd1: temp_result_0 <= str_0[7:0];
                        4'd2: temp_result_0 <= str_0[15:8];
                        4'd3: temp_result_0 <= str_0[23:16];
                        4'd4: temp_result_0 <= str_0[31:24];
                        4'd5: temp_result_0 <= str_0[39:32];
                        4'd6: temp_result_0 <= str_0[47:40];
                        4'd7: temp_result_0 <= str_0[55:48];
                        4'd8: temp_result_0 <= str_0[63:56];
                        default: temp_result_0 <= 8'd0;
                    endcase

                    case (len_1)
                        4'd1: temp_result_1 <= str_1[7:0];
                        4'd2: temp_result_1 <= str_1[15:8];
                        4'd3: temp_result_1 <= str_1[23:16];
                        4'd4: temp_result_1 <= str_1[31:24];
                        4'd5: temp_result_1 <= str_1[39:32];
                        4'd6: temp_result_1 <= str_1[47:40];
                        4'd7: temp_result_1 <= str_1[55:48];
                        4'd8: temp_result_1 <= str_1[63:56];
                        default: temp_result_1 <= 8'd0;
                    endcase

                    case (len_2)
                        4'd1: temp_result_2 <= str_2[7:0];
                        4'd2: temp_result_2 <= str_2[15:8];
                        4'd3: temp_result_2 <= str_2[23:16];
                        4'd4: temp_result_2 <= str_2[31:24];
                        4'd5: temp_result_2 <= str_2[39:32];
                        4'd6: temp_result_2 <= str_2[47:40];
                        4'd7: temp_result_2 <= str_2[55:48];
                        4'd8: temp_result_2 <= str_2[63:56];
                        default: temp_result_2 <= 8'd0;
                    endcase

                    state <= OUTPUT;
                end

                OUTPUT: begin
                    result_0 <= temp_result_0;
                    result_1 <= temp_result_1;
                    result_2 <= temp_result_2;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule