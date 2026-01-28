module find_single_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [7:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [3:0] idx;
    reg [7:0] xor_accum;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            idx <= 4'd0;
            xor_accum <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        idx <= 4'd0;
                        xor_accum <= 8'd0;
                    end
                end
                
                COMPUTE: begin
                    if (idx < len) begin
                        case (idx)
                            4'd0: xor_accum <= xor_accum ^ arr_0;
                            4'd1: xor_accum <= xor_accum ^ arr_1;
                            4'd2: xor_accum <= xor_accum ^ arr_2;
                            4'd3: xor_accum <= xor_accum ^ arr_3;
                            4'd4: xor_accum <= xor_accum ^ arr_4;
                            4'd5: xor_accum <= xor_accum ^ arr_5;
                            4'd6: xor_accum <= xor_accum ^ arr_6;
                            4'd7: xor_accum <= xor_accum ^ arr_7;
                            default: xor_accum <= xor_accum;
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= xor_accum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule