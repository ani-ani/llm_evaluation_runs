module string_generator(
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    output reg [7:0] char_0,
    output reg [7:0] char_1,
    output reg [7:0] char_2,
    output reg [7:0] char_3,
    output reg [7:0] char_4,
    output reg [7:0] char_5,
    output reg [7:0] char_6,
    output reg [7:0] char_7,
    output reg [7:0] char_8,
    output reg [7:0] char_9,
    output reg [7:0] char_10,
    output reg [7:0] char_11,
    output reg [7:0] char_12,
    output reg [7:0] char_13,
    output reg [7:0] char_14,
    output reg [7:0] char_15,
    output reg [7:0] char_16,
    output reg [7:0] char_17,
    output reg [7:0] char_18,
    output reg [7:0] char_19,
    output reg [7:0] char_20,
    output reg [7:0] char_21,
    output reg [7:0] char_22,
    output reg [7:0] char_23,
    output reg [7:0] char_24,
    output reg [7:0] char_25,
    output reg [7:0] char_26,
    output reg [7:0] char_27,
    output reg [7:0] char_28,
    output reg [7:0] char_29,
    output reg [7:0] char_30,
    output reg [7:0] char_31,
    output reg [7:0] char_32,
    output reg [7:0] char_33,
    output reg [7:0] char_34,
    output reg [7:0] char_35,
    output reg [7:0] char_36,
    output reg [7:0] char_37,
    output reg [7:0] char_38,
    output reg [7:0] char_39,
    output reg [7:0] char_40,
    output reg [7:0] char_41,
    output reg [7:0] char_42,
    output reg [7:0] char_43,
    output reg [7:0] char_44,
    output reg [7:0] char_45,
    output reg [7:0] char_46,
    output reg [7:0] char_47,
    output reg [7:0] char_48,
    output reg [7:0] char_49,
    output reg [7:0] char_50,
    output reg [7:0] char_51,
    output reg [7:0] char_52,
    output reg [7:0] char_53,
    output reg [7:0] char_54,
    output reg [7:0] char_55,
    output reg [7:0] char_56,
    output reg [7:0] char_57,
    output reg [7:0] char_58,
    output reg [7:0] char_59,
    output reg [7:0] char_60,
    output reg [7:0] char_61,
    output reg [7:0] char_62,
    output reg [7:0] char_63,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] GENERATING = 2'd1;
    localparam [1:0] COMPLETE = 2'd2;

    reg [1:0] state;
    reg [3:0] current_num;
    reg [5:0] char_index;
    reg [7:0] char_array [0:63];
    reg [3:0] num_chars;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_num <= 4'd0;
            char_index <= 6'd0;
            done <= 1'b0;
            char_0 <= 8'd0;
            char_1 <= 8'd0;
            char_2 <= 8'd0;
            char_3 <= 8'd0;
            char_4 <= 8'd0;
            char_5 <= 8'd0;
            char_6 <= 8'd0;
            char_7 <= 8'd0;
            char_8 <= 8'd0;
            char_9 <= 8'd0;
            char_10 <= 8'd0;
            char_11 <= 8'd0;
            char_12 <= 8'd0;
            char_13 <= 8'd0;
            char_14 <= 8'd0;
            char_15 <= 8'd0;
            char_16 <= 8'd0;
            char_17 <= 8'd0;
            char_18 <= 8'd0;
            char_19 <= 8'd0;
            char_20 <= 8'd0;
            char_21 <= 8'd0;
            char_22 <= 8'd0;
            char_23 <= 8'd0;
            char_24 <= 8'd0;
            char_25 <= 8'd0;
            char_26 <= 8'd0;
            char_27 <= 8'd0;
            char_28 <= 8'd0;
            char_29 <= 8'd0;
            char_30 <= 8'd0;
            char_31 <= 8'd0;
            char_32 <= 8'd0;
            char_33 <= 8'd0;
            char_34 <= 8'd0;
            char_35 <= 8'd0;
            char_36 <= 8'd0;
            char_37 <= 8'd0;
            char_38 <= 8'd0;
            char_39 <= 8'd0;
            char_40 <= 8'd0;
            char_41 <= 8'd0;
            char_42 <= 8'd0;
            char_43 <= 8'd0;
            char_44 <= 8'd0;
            char_45 <= 8'd0;
            char_46 <= 8'd0;
            char_47 <= 8'd0;
            char_48 <= 8'd0;
            char_49 <= 8'd0;
            char_50 <= 8'd0;
            char_51 <= 8'd0;
            char_52 <= 8'd0;
            char_53 <= 8'd0;
            char_54 <= 8'd0;
            char_55 <= 8'd0;
            char_56 <= 8'd0;
            char_57 <= 8'd0;
            char_58 <= 8'd0;
            char_59 <= 8'd0;
            char_60 <= 8'd0;
            char_61 <= 8'd0;
            char_62 <= 8'd0;
            char_63 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= GENERATING;
                        current_num <= 4'd0;
                        char_index <= 6'd0;
                        num_chars <= 4'd0;
                    end
                end

                GENERATING: begin
                    if (current_num <= n) begin
                        if (current_num > 0) begin
                            char_array[char_index] <= 8'd32;
                            char_index <= char_index + 6'd1;
                            num_chars <= num_chars + 4'd1;
                        end

                        if (current_num < 10) begin
                            char_array[char_index] <= 8'd48 + current_num;
                            char_index <= char_index + 6'd1;
                            num_chars <= num_chars + 4'd1;
                        end else begin
                            char_array[char_index] <= 8'd49;
                            char_index <= char_index + 6'd1;
                            char_array[char_index] <= 8'd48 + (current_num - 10);
                            char_index <= char_index + 6'd1;
                            num_chars <= num_chars + 4'd2;
                        end

                        current_num <= current_num + 4'd1;
                    end else begin
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

    always @(*) begin
        char_0 <= char_array[0];
        char_1 <= char_array[1];
        char_2 <= char_array[2];
        char_3 <= char_array[3];
        char_4 <= char_array[4];
        char_5 <= char_array[5];
        char_6 <= char_array[6];
        char_7 <= char_array[7];
        char_8 <= char_array[8];
        char_9 <= char_array[9];
        char_10 <= char_array[10];
        char_11 <= char_array[11];
        char_12 <= char_array[12];
        char_13 <= char_array[13];
        char_14 <= char_array[14];
        char_15 <= char_array[15];
        char_16 <= char_array[16];
        char_17 <= char_array[17];
        char_18 <= char_array[18];
        char_19 <= char_array[19];
        char_20 <= char_array[20];
        char_21 <= char_array[21];
        char_22 <= char_array[22];
        char_23 <= char_array[23];
        char_24 <= char_array[24];
        char_25 <= char_array[25];
        char_26 <= char_array[26];
        char_27 <= char_array[27];
        char_28 <= char_array[28];
        char_29 <= char_array[29];
        char_30 <= char_array[30];
        char_31 <= char_array[31];
        char_32 <= char_array[32];
        char_33 <= char_array[33];
        char_34 <= char_array[34];
        char_35 <= char_array[35];
        char_36 <= char_array[36];
        char_37 <= char_array[37];
        char_38 <= char_array[38];
        char_39 <= char_array[39];
        char_40 <= char_array[40];
        char_41 <= char_array[41];
        char_42 <= char_array[42];
        char_43 <= char_array[43];
        char_44 <= char_array[44];
        char_45 <= char_array[45];
        char_46 <= char_array[46];
        char_47 <= char_array[47];
        char_48 <= char_array[48];
        char_49 <= char_array[49];
        char_50 <= char_array[50];
        char_51 <= char_array[51];
        char_52 <= char_array[52];
        char_53 <= char_array[53];
        char_54 <= char_array[54];
        char_55 <= char_array[55];
        char_56 <= char_array[56];
        char_57 <= char_array[57];
        char_58 <= char_array[58];
        char_59 <= char_array[59];
        char_60 <= char_array[60];
        char_61 <= char_array[61];
        char_62 <= char_array[62];
        char_63 <= char_array[63];
    end

endmodule