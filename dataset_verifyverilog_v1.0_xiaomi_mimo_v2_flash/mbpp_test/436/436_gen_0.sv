module find_negatives(
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
    input wire [2:0] len,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [2:0] result_len,
    output reg done
);

    reg [2:0] state;
    reg [2:0] idx;
    reg [2:0] out_idx;
    reg [2:0] cycle_count;
    localparam [2:0] MAX_CYCLES = 3'd8;
    
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] COMPLETE = 3'd2;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 3'd0;
            out_idx <= 3'd0;
            result_len <= 3'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            done <= 1'b0;
            cycle_count <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 3'd0;
                    if (start) begin
                        state <= PROCESS;
                        idx <= 3'd0;
                        out_idx <= 3'd0;
                        result_len <= 3'd0;
                        result_0 <= 8'd0;
                        result_1 <= 8'd0;
                        result_2 <= 8'd0;
                        result_3 <= 8'd0;
                        result_4 <= 8'd0;
                        result_5 <= 8'd0;
                        result_6 <= 8'd0;
                        result_7 <= 8'd0;
                    end
                end
                
                PROCESS: begin
                    cycle_count <= cycle_count + 1'b1;
                    if (idx < len && cycle_count < MAX_CYCLES) begin
                        case (idx)
                            3'd0: if (arr_0[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_0;
                                    3'd1: result_1 <= arr_0;
                                    3'd2: result_2 <= arr_0;
                                    3'd3: result_3 <= arr_0;
                                    3'd4: result_4 <= arr_0;
                                    3'd5: result_5 <= arr_0;
                                    3'd6: result_6 <= arr_0;
                                    3'd7: result_7 <= arr_0;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd1: if (arr_1[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_1;
                                    3'd1: result_1 <= arr_1;
                                    3'd2: result_2 <= arr_1;
                                    3'd3: result_3 <= arr_1;
                                    3'd4: result_4 <= arr_1;
                                    3'd5: result_5 <= arr_1;
                                    3'd6: result_6 <= arr_1;
                                    3'd7: result_7 <= arr_1;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd2: if (arr_2[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_2;
                                    3'd1: result_1 <= arr_2;
                                    3'd2: result_2 <= arr_2;
                                    3'd3: result_3 <= arr_2;
                                    3'd4: result_4 <= arr_2;
                                    3'd5: result_5 <= arr_2;
                                    3'd6: result_6 <= arr_2;
                                    3'd7: result_7 <= arr_2;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd3: if (arr_3[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_3;
                                    3'd1: result_1 <= arr_3;
                                    3'd2: result_2 <= arr_3;
                                    3'd3: result_3 <= arr_3;
                                    3'd4: result_4 <= arr_3;
                                    3'd5: result_5 <= arr_3;
                                    3'd6: result_6 <= arr_3;
                                    3'd7: result_7 <= arr_3;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd4: if (arr_4[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_4;
                                    3'd1: result_1 <= arr_4;
                                    3'd2: result_2 <= arr_4;
                                    3'd3: result_3 <= arr_4;
                                    3'd4: result_4 <= arr_4;
                                    3'd5: result_5 <= arr_4;
                                    3'd6: result_6 <= arr_4;
                                    3'd7: result_7 <= arr_4;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd5: if (arr_5[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_5;
                                    3'd1: result_1 <= arr_5;
                                    3'd2: result_2 <= arr_5;
                                    3'd3: result_3 <= arr_5;
                                    3'd4: result_4 <= arr_5;
                                    3'd5: result_5 <= arr_5;
                                    3'd6: result_6 <= arr_5;
                                    3'd7: result_7 <= arr_5;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd6: if (arr_6[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_6;
                                    3'd1: result_1 <= arr_6;
                                    3'd2: result_2 <= arr_6;
                                    3'd3: result_3 <= arr_6;
                                    3'd4: result_4 <= arr_6;
                                    3'd5: result_5 <= arr_6;
                                    3'd6: result_6 <= arr_6;
                                    3'd7: result_7 <= arr_6;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                            3'd7: if (arr_7[7]) begin
                                case (out_idx)
                                    3'd0: result_0 <= arr_7;
                                    3'd1: result_1 <= arr_7;
                                    3'd2: result_2 <= arr_7;
                                    3'd3: result_3 <= arr_7;
                                    3'd4: result_4 <= arr_7;
                                    3'd5: result_5 <= arr_7;
                                    3'd6: result_6 <= arr_7;
                                    3'd7: result_7 <= arr_7;
                                endcase
                                out_idx <= out_idx + 1'b1;
                            end
                        endcase
                        idx <= idx + 1'b1;
                    end else begin
                        result_len <= out_idx;
                        state <= COMPLETE;
                    end
                end
                
                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule