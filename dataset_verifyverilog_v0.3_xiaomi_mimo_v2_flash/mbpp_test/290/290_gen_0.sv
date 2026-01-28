module max_length (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0_0, arr_0_1, arr_0_2, arr_0_3, arr_0_4, arr_0_5, arr_0_6, arr_0_7,
    input wire [7:0] arr_1_0, arr_1_1, arr_1_2, arr_1_3, arr_1_4, arr_1_5, arr_1_6, arr_1_7,
    input wire [7:0] arr_2_0, arr_2_1, arr_2_2, arr_2_3, arr_2_4, arr_2_5, arr_2_6, arr_2_7,
    input wire [7:0] arr_3_0, arr_3_1, arr_3_2, arr_3_3, arr_3_4, arr_3_5, arr_3_6, arr_3_7,
    input wire [7:0] arr_4_0, arr_4_1, arr_4_2, arr_4_3, arr_4_4, arr_4_5, arr_4_6, arr_4_7,
    input wire [7:0] arr_5_0, arr_5_1, arr_5_2, arr_5_3, arr_5_4, arr_5_5, arr_5_6, arr_5_7,
    input wire [7:0] arr_6_0, arr_6_1, arr_6_2, arr_6_3, arr_6_4, arr_6_5, arr_6_6, arr_6_7,
    input wire [7:0] arr_7_0, arr_7_1, arr_7_2, arr_7_3, arr_7_4, arr_7_5, arr_7_6, arr_7_7,
    input wire [3:0] len_0, len_1, len_2, len_3, len_4, len_5, len_6, len_7,
    output reg [3:0] max_len,
    output reg [7:0] max_list_0, max_list_1, max_list_2, max_list_3,
    output reg [7:0] max_list_4, max_list_5, max_list_6, max_list_7,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] sublist_idx;
    reg [3:0] max_len_reg;
    reg [2:0] longest_idx;
    reg [3:0] copy_count;
    
    reg [7:0] arr_storage_0 [0:7];
    reg [7:0] arr_storage_1 [0:7];
    reg [7:0] arr_storage_2 [0:7];
    reg [7:0] arr_storage_3 [0:7];
    reg [7:0] arr_storage_4 [0:7];
    reg [7:0] arr_storage_5 [0:7];
    reg [7:0] arr_storage_6 [0:7];
    reg [7:0] arr_storage_7 [0:7];
    
    reg [3:0] lens_storage [0:7];
    
    integer i;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_len <= 4'd0;
            max_len_reg <= 4'd0;
            done <= 1'b0;
            sublist_idx <= 3'd0;
            longest_idx <= 3'd0;
            copy_count <= 4'd0;
            
            max_list_0 <= 8'd0;
            max_list_1 <= 8'd0;
            max_list_2 <= 8'd0;
            max_list_3 <= 8'd0;
            max_list_4 <= 8'd0;
            max_list_5 <= 8'd0;
            max_list_6 <= 8'd0;
            max_list_7 <= 8'd0;
            
            for (i = 0; i < 8; i = i + 1) begin
                lens_storage[i] <= 4'd0;
            end
            
            arr_storage_0[0] <= 8'd0; arr_storage_0[1] <= 8'd0; arr_storage_0[2] <= 8'd0; arr_storage_0[3] <= 8'd0;
            arr_storage_0[4] <= 8'd0; arr_storage_0[5] <= 8'd0; arr_storage_0[6] <= 8'd0; arr_storage_0[7] <= 8'd0;
            arr_storage_1[0] <= 8'd0; arr_storage_1[1] <= 8'd0; arr_storage_1[2] <= 8'd0; arr_storage_1[3] <= 8'd0;
            arr_storage_1[4] <= 8'd0; arr_storage_1[5] <= 8'd0; arr_storage_1[6] <= 8'd0; arr_storage_1[7] <= 8'd0;
            arr_storage_2[0] <= 8'd0; arr_storage_2[1] <= 8'd0; arr_storage_2[2] <= 8'd0; arr_storage_2[3] <= 8'd0;
            arr_storage_2[4] <= 8'd0; arr_storage_2[5] <= 8'd0; arr_storage_2[6] <= 8'd0; arr_storage_2[7] <= 8'd0;
            arr_storage_3[0] <= 8'd0; arr_storage_3[1] <= 8'd0; arr_storage_3[2] <= 8'd0; arr_storage_3[3] <= 8'd0;
            arr_storage_3[4] <= 8'd0; arr_storage_3[5] <= 8'd0; arr_storage_3[6] <= 8'd0; arr_storage_3[7] <= 8'd0;
            arr_storage_4[0] <= 8'd0; arr_storage_4[1] <= 8'd0; arr_storage_4[2] <= 8'd0; arr_storage_4[3] <= 8'd0;
            arr_storage_4[4] <= 8'd0; arr_storage_4[5] <= 8'd0; arr_storage_4[6] <= 8'd0; arr_storage_4[7] <= 8'd0;
            arr_storage_5[0] <= 8'd0; arr_storage_5[1] <= 8'd0; arr_storage_5[2] <= 8'd0; arr_storage_5[3] <= 8'd0;
            arr_storage_5[4] <= 8'd0; arr_storage_5[5] <= 8'd0; arr_storage_5[6] <= 8'd0; arr_storage_5[7] <= 8'd0;
            arr_storage_6[0] <= 8'd0; arr_storage_6[1] <= 8'd0; arr_storage_6[2] <= 8'd0; arr_storage_6[3] <= 8'd0;
            arr_storage_6[4] <= 8'd0; arr_storage_6[5] <= 8'd0; arr_storage_6[6] <= 8'd0; arr_storage_6[7] <= 8'd0;
            arr_storage_7[0] <= 8'd0; arr_storage_7[1] <= 8'd0; arr_storage_7[2] <= 8'd0; arr_storage_7[3] <= 8'd0;
            arr_storage_7[4] <= 8'd0; arr_storage_7[5] <= 8'd0; arr_storage_7[6] <= 8'd0; arr_storage_7[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        arr_storage_0[0] <= arr_0_0; arr_storage_0[1] <= arr_0_1; arr_storage_0[2] <= arr_0_2; arr_storage_0[3] <= arr_0_3;
                        arr_storage_0[4] <= arr_0_4; arr_storage_0[5] <= arr_0_5; arr_storage_0[6] <= arr_0_6; arr_storage_0[7] <= arr_0_7;
                        arr_storage_1[0] <= arr_1_0; arr_storage_1[1] <= arr_1_1; arr_storage_1[2] <= arr_1_2; arr_storage_1[3] <= arr_1_3;
                        arr_storage_1[4] <= arr_1_4; arr_storage_1[5] <= arr_1_5; arr_storage_1[6] <= arr_1_6; arr_storage_1[7] <= arr_1_7;
                        arr_storage_2[0] <= arr_2_0; arr_storage_2[1] <= arr_2_1; arr_storage_2[2] <= arr_2_2; arr_storage_2[3] <= arr_2_3;
                        arr_storage_2[4] <= arr_2_4; arr_storage_2[5] <= arr_2_5; arr_storage_2[6] <= arr_2_6; arr_storage_2[7] <= arr_2_7;
                        arr_storage_3[0] <= arr_3_0; arr_storage_3[1] <= arr_3_1; arr_storage_3[2] <= arr_3_2; arr_storage_3[3] <= arr_3_3;
                        arr_storage_3[4] <= arr_3_4; arr_storage_3[5] <= arr_3_5; arr_storage_3[6] <= arr_3_6; arr_storage_3[7] <= arr_3_7;
                        arr_storage_4[0] <= arr_4_0; arr_storage_4[1] <= arr_4_1; arr_storage_4[2] <= arr_4_2; arr_storage_4[3] <= arr_4_3;
                        arr_storage_4[4] <= arr_4_4; arr_storage_4[5] <= arr_4_5; arr_storage_4[6] <= arr_4_6; arr_storage_4[7] <= arr_4_7;
                        arr_storage_5[0] <= arr_5_0; arr_storage_5[1] <= arr_5_1; arr_storage_5[2] <= arr_5_2; arr_storage_5[3] <= arr_5_3;
                        arr_storage_5[4] <= arr_5_4; arr_storage_5[5] <= arr_5_5; arr_storage_5[6] <= arr_5_6; arr_storage_5[7] <= arr_5_7;
                        arr_storage_6[0] <= arr_6_0; arr_storage_6[1] <= arr_6_1; arr_storage_6[2] <= arr_6_2; arr_storage_6[3] <= arr_6_3;
                        arr_storage_6[4] <= arr_6_4; arr_storage_6[5] <= arr_6_5; arr_storage_6[6] <= arr_6_6; arr_storage_6[7] <= arr_6_7;
                        arr_storage_7[0] <= arr_7_0; arr_storage_7[1] <= arr_7_1; arr_storage_7[2] <= arr_7_2; arr_storage_7[3] <= arr_7_3;
                        arr_storage_7[4] <= arr_7_4; arr_storage_7[5] <= arr_7_5; arr_storage_7[6] <= arr_7_6; arr_storage_7[7] <= arr_7_7;
                        lens_storage[0] <= len_0; lens_storage[1] <= len_1; lens_storage[2] <= len_2; lens_storage[3] <= len_3;
                        lens_storage[4] <= len_4; lens_storage[5] <= len_5; lens_storage[6] <= len_6; lens_storage[7] <= len_7;
                        sublist_idx <= 3'd0;
                        max_len_reg <= 4'd0;
                        longest_idx <= 3'd0;
                        state <= COMPUTE;
                    end
                end
                COMPUTE: begin
                    if (lens_storage[sublist_idx] > max_len_reg) begin
                        max_len_reg <= lens_storage[sublist_idx];
                        longest_idx <= sublist_idx;
                    end
                    if (sublist_idx < 3'd7) begin
                        sublist_idx <= sublist_idx + 3'd1;
                    end else begin
                        max_len <= max_len_reg;
                        if (max_len_reg > 4'd0) begin
                            copy_count <= 4'd0;
                            state <= FINISH;
                        end else begin
                            done <= 1'b1;
                            state <= IDLE;
                        end
                    end
                end
                FINISH: begin
                    if (copy_count < max_len_reg) begin
                        case (longest_idx)
                            3'd0: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_0[0];
                                    4'd1: max_list_1 <= arr_storage_0[1];
                                    4'd2: max_list_2 <= arr_storage_0[2];
                                    4'd3: max_list_3 <= arr_storage_0[3];
                                    4'd4: max_list_4 <= arr_storage_0[4];
                                    4'd5: max_list_5 <= arr_storage_0[5];
                                    4'd6: max_list_6 <= arr_storage_0[6];
                                    4'd7: max_list_7 <= arr_storage_0[7];
                                endcase
                            end
                            3'd1: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_1[0];
                                    4'd1: max_list_1 <= arr_storage_1[1];
                                    4'd2: max_list_2 <= arr_storage_1[2];
                                    4'd3: max_list_3 <= arr_storage_1[3];
                                    4'd4: max_list_4 <= arr_storage_1[4];
                                    4'd5: max_list_5 <= arr_storage_1[5];
                                    4'd6: max_list_6 <= arr_storage_1[6];
                                    4'd7: max_list_7 <= arr_storage_1[7];
                                endcase
                            end
                            3'd2: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_2[0];
                                    4'd1: max_list_1 <= arr_storage_2[1];
                                    4'd2: max_list_2 <= arr_storage_2[2];
                                    4'd3: max_list_3 <= arr_storage_2[3];
                                    4'd4: max_list_4 <= arr_storage_2[4];
                                    4'd5: max_list_5 <= arr_storage_2[5];
                                    4'd6: max_list_6 <= arr_storage_2[6];
                                    4'd7: max_list_7 <= arr_storage_2[7];
                                endcase
                            end
                            3'd3: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_3[0];
                                    4'd1: max_list_1 <= arr_storage_3[1];
                                    4'd2: max_list_2 <= arr_storage_3[2];
                                    4'd3: max_list_3 <= arr_storage_3[3];
                                    4'd4: max_list_4 <= arr_storage_3[4];
                                    4'd5: max_list_5 <= arr_storage_3[5];
                                    4'd6: max_list_6 <= arr_storage_3[6];
                                    4'd7: max_list_7 <= arr_storage_3[7];
                                endcase
                            end
                            3'd4: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_4[0];
                                    4'd1: max_list_1 <= arr_storage_4[1];
                                    4'd2: max_list_2 <= arr_storage_4[2];
                                    4'd3: max_list_3 <= arr_storage_4[3];
                                    4'd4: max_list_4 <= arr_storage_4[4];
                                    4'd5: max_list_5 <= arr_storage_4[5];
                                    4'd6: max_list_6 <= arr_storage_4[6];
                                    4'd7: max_list_7 <= arr_storage_4[7];
                                endcase
                            end
                            3'd5: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_5[0];
                                    4'd1: max_list_1 <= arr_storage_5[1];
                                    4'd2: max_list_2 <= arr_storage_5[2];
                                    4'd3: max_list_3 <= arr_storage_5[3];
                                    4'd4: max_list_4 <= arr_storage_5[4];
                                    4'd5: max_list_5 <= arr_storage_5[5];
                                    4'd6: max_list_6 <= arr_storage_5[6];
                                    4'd7: max_list_7 <= arr_storage_5[7];
                                endcase
                            end
                            3'd6: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_6[0];
                                    4'd1: max_list_1 <= arr_storage_6[1];
                                    4'd2: max_list_2 <= arr_storage_6[2];
                                    4'd3: max_list_3 <= arr_storage_6[3];
                                    4'd4: max_list_4 <= arr_storage_6[4];
                                    4'd5: max_list_5 <= arr_storage_6[5];
                                    4'd6: max_list_6 <= arr_storage_6[6];
                                    4'd7: max_list_7 <= arr_storage_6[7];
                                endcase
                            end
                            3'd7: begin
                                case (copy_count)
                                    4'd0: max_list_0 <= arr_storage_7[0];
                                    4'd1: max_list_1 <= arr_storage_7[1];
                                    4'd2: max_list_2 <= arr_storage_7[2];
                                    4'd3: max_list_3 <= arr_storage_7[3];
                                    4'd4: max_list_4 <= arr_storage_7[4];
                                    4'd5: max_list_5 <= arr_storage_7[5];
                                    4'd6: max_list_6 <= arr_storage_7[6];
                                    4'd7: max_list_7 <= arr_storage_7[7];
                                endcase
                            end
                        endcase
                        copy_count <= copy_count + 4'd1;
                    end else begin
                        done <= 1'b1;
                        state <= IDLE;
                    end
                end
                default: state <= IDLE;
            endcase
        end
    end

endmodule