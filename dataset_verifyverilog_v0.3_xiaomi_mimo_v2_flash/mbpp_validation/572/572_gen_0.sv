module find_unique_numbers (
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
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg [3:0] result_len,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] STORE   = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] FINISH  = 3'd4;

    reg [2:0] state;
    reg [3:0] idx;
    reg [3:0] out_idx;
    reg [7:0] freq_table [0:255];
    reg [7:0] input_reg [0:7];
    reg [3:0] len_reg;
    reg [7:0] current_val;
    
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result_len <= 4'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
            result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
            result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
            len_reg <= 4'd0;
            current_val <= 8'd0;
            for (i = 0; i < 256; i = i + 1) begin
                freq_table[i] <= 8'd0;
            end
            for (i = 0; i < 8; i = i + 1) begin
                input_reg[i] <= 8'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    idx <= 4'd0;
                    out_idx <= 4'd0;
                    result_len <= 4'd0;
                    result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
                    result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
                    if (start) begin
                        len_reg <= len;
                        state <= STORE;
                    end
                end

                STORE: begin
                    if (idx < 8'd8) begin
                        case (idx)
                            4'd0: input_reg[0] <= arr_0;
                            4'd1: input_reg[1] <= arr_1;
                            4'd2: input_reg[2] <= arr_2;
                            4'd3: input_reg[3] <= arr_3;
                            4'd4: input_reg[4] <= arr_4;
                            4'd5: input_reg[5] <= arr_5;
                            4'd6: input_reg[6] <= arr_6;
                            4'd7: input_reg[7] <= arr_7;
                            default: begin end
                        endcase
                        idx <= idx + 4'd1;
                    end else begin
                        // Reset frequency table
                        for (i = 0; i < 256; i = i + 1) begin
                            freq_table[i] <= 8'd0;
                        end
                        idx <= 4'd0;
                        state <= COUNT;
                    end
                end

                COUNT: begin
                    if (idx < len_reg) begin
                        current_val <= input_reg[idx];
                        freq_table[input_reg[idx]] <= freq_table[input_reg[idx]] + 8'd1;
                        idx <= idx + 4'd1;
                    end else begin
                        idx <= 4'd0;
                        state <= OUTPUT;
                    end
                end

                OUTPUT: begin
                    if (idx < len_reg) begin
                        current_val <= input_reg[idx];
                        if (freq_table[input_reg[idx]] == 8'd1) begin
                            if (out_idx < 4'd8) begin
                                case (out_idx)
                                    4'd0: result_0 <= input_reg[idx];
                                    4'd1: result_1 <= input_reg[idx];
                                    4'd2: result_2 <= input_reg[idx];
                                    4'd3: result_3 <= input_reg[idx];
                                    4'd4: result_4 <= input_reg[idx];
                                    4'd5: result_5 <= input_reg[idx];
                                    4'd6: result_6 <= input_reg[idx];
                                    4'd7: result_7 <= input_reg[idx];
                                    default: begin end
                                endcase
                                result_len <= result_len + 4'd1;
                            end
                            out_idx <= out_idx + 4'd1;
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule