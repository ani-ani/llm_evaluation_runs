module voodoo_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] N,
    input wire [7:0] P,
    input wire [7:0] arr_0, arr_1, arr_2, arr_3,
                     arr_4, arr_5, arr_6, arr_7,
    output reg [5:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] INIT       = 3'd1;
    localparam [2:0] PREFIX     = 3'd2;
    localparam [2:0] COUNT_INIT = 3'd3;
    localparam [2:0] COUNT_LOOP = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state;
    reg signed [11:0] prefix [0:8];
    reg [3:0] i_cnt, j_cnt;
    reg [5:0] temp_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Compute b_i = arr_i - P (signed 9-bit)
    wire signed [8:0] b_0 = $signed(arr_0) - $signed(P);
    wire signed [8:0] b_1 = $signed(arr_1) - $signed(P);
    wire signed [8:0] b_2 = $signed(arr_2) - $signed(P);
    wire signed [8:0] b_3 = $signed(arr_3) - $signed(P);
    wire signed [8:0] b_4 = $signed(arr_4) - $signed(P);
    wire signed [8:0] b_5 = $signed(arr_5) - $signed(P);
    wire signed [8:0] b_6 = $signed(arr_6) - $signed(P);
    wire signed [8:0] b_7 = $signed(arr_7) - $signed(P);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 6'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_cnt <= 4'd0;
            j_cnt <= 4'd0;
            temp_result <= 6'd0;
            prefix[0] <= 12'd0;
            prefix[1] <= 12'd0;
            prefix[2] <= 12'd0;
            prefix[3] <= 12'd0;
            prefix[4] <= 12'd0;
            prefix[5] <= 12'd0;
            prefix[6] <= 12'd0;
            prefix[7] <= 12'd0;
            prefix[8] <= 12'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= INIT;
                    end
                end

                INIT: begin
                    prefix[0] <= 12'd0;
                    i_cnt <= 4'd0;
                    state <= PREFIX;
                end

                PREFIX: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (i_cnt < N) begin
                        case (i_cnt)
                            4'd0: prefix[1] <= prefix[0] + b_0;
                            4'd1: prefix[2] <= prefix[1] + b_1;
                            4'd2: prefix[3] <= prefix[2] + b_2;
                            4'd3: prefix[4] <= prefix[3] + b_3;
                            4'd4: prefix[5] <= prefix[4] + b_4;
                            4'd5: prefix[6] <= prefix[5] + b_5;
                            4'd6: prefix[7] <= prefix[6] + b_6;
                            4'd7: prefix[8] <= prefix[7] + b_7;
                            default: prefix[i_cnt + 1] <= prefix[i_cnt];
                        endcase
                        i_cnt <= i_cnt + 4'd1;
                    end else begin
                        state <= COUNT_INIT;
                    end
                end

                COUNT_INIT: begin
                    i_cnt <= 4'd0;
                    j_cnt <= 4'd1;
                    temp_result <= 6'd0;
                    state <= COUNT_LOOP;
                end

                COUNT_LOOP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (prefix[i_cnt] <= prefix[j_cnt]) begin
                        temp_result <= temp_result + 6'd1;
                    end
                    if (j_cnt < N + 4'd1) begin
                        j_cnt <= j_cnt + 4'd1;
                    end else begin
                        if (i_cnt < N) begin
                            i_cnt <= i_cnt + 4'd1;
                            j_cnt <= i_cnt + 4'd1;
                        end else begin
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule