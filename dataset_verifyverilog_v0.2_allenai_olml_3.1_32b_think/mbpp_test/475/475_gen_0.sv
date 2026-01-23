module dict_sorter (
    input clk,
    input rst_n,
    input start,
    input [7:0] key_0, key_1, key_2, key_3, key_4, key_5, key_6, key_7,
    input [15:0] value_0, value_1, value_2, value_3, value_4, value_5, value_6, value_7,
    output reg [7:0] out_key_0, out_key_1, out_key_2, out_key_3,
    output reg [15:0] out_value_0, out_value_1, out_value_2, out_value_3,
    output reg done
);

    reg [7:0] key_reg [7:0];
    reg [15:0] value_reg [7:0];
    reg [4:0] state;
    reg [7:0] temp_key;
    reg [15:0] temp_value;

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= 0;
            key_reg <= 0;
            value_reg <= 0;
            out_key_0 <= 8'b0;
            out_key_1 <= 8'b0;
            out_key_2 <= 8'b0;
            out_key_3 <= 8'b0;
            out_value_0 <= 16'b0;
            out_value_1 <= 16'b0;
            out_value_2 <= 16'b0;
            out_value_3 <= 16'b0;
            done <= 0;
        end else begin
            case(state)
                0: begin
                    if (start) begin
                        key_reg[0] <= key_0;
                        key_reg[1] <= key_1;
                        key_reg[2] <= key_2;
                        key_reg[3] <= key_3;
                        key_reg[4] <= key_4;
                        key_reg[5] <= key_5;
                        key_reg[6] <= key_6;
                        key_reg[7] <= key_7;
                        value_reg[0] <= value_0;
                        value_reg[1] <= value_1;
                        value_reg[2] <= value_2;
                        value_reg[3] <= value_3;
                        value_reg[4] <= value_4;
                        value_reg[5] <= value_5;
                        value_reg[6] <= value_6;
                        value_reg[7] <= value_7;
                        state <= 1;
                    end else begin
                        state <= 0;
                        out_key_0 <= 8'b0;
                        out_key_1 <= 8'b0;
                        out_key_2 <= 8'b0;
                        out_key_3 <= 8'b0;
                        out_value_0 <= 16'b0;
                        out_value_1 <= 16'b0;
                        out_value_2 <= 16'b0;
                        out_value_3 <= 16'b0;
                        done <= 0;
                    end
                end
                1: begin
                    integer i;
                    i = (1-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (1 < 28) state <= 2; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                2: begin
                    integer i;
                    i = (2-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (2 < 28) state <= 3; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                3: begin
                    integer i;
                    i = (3-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (3 < 28) state <= 4; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                4: begin
                    integer i;
                    i = (4-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (4 < 28) state <= 5; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                5: begin
                    integer i;
                    i = (5-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (5 < 28) state <= 6; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                6: begin
                    integer i;
                    i = (6-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (6 < 28) state <= 7; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                7: begin
                    integer i;
                    i = (7-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (7 < 28) state <= 8; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                8: begin
                    integer i;
                    i = (8-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (8 < 28) state <= 9; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                9: begin
                    integer i;
                    i = (9-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (9 < 28) state <= 10; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                10: begin
                    integer i;
                    i = (10-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (10 < 28) state <= 11; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                11: begin
                    integer i;
                    i = (11-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (11 < 28) state <= 12; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                12: begin
                    integer i;
                    i = (12-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (12 < 28) state <= 13; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                13: begin
                    integer i;
                    i = (13-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (13 < 28) state <= 14; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                14: begin
                    integer i;
                    i = (14-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (14 < 28) state <= 15; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                15: begin
                    integer i;
                    i = (15-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (15 < 28) state <= 16; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                16: begin
                    integer i;
                    i = (16-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (16 < 28) state <= 17; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                17: begin
                    integer i;
                    i = (17-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (17 < 28) state <= 18; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                18: begin
                    integer i;
                    i = (18-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (18 < 28) state <= 19; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                19: begin
                    integer i;
                    i = (19-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (19 < 28) state <= 20; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                20: begin
                    integer i;
                    i = (20-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (20 < 28) state <= 21; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                21: begin
                    integer i;
                    i = (21-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (21 < 28) state <= 22; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                22: begin
                    integer i;
                    i = (22-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (22 < 28) state <= 23; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                23: begin
                    integer i;
                    i = (23-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (23 < 28) state <= 24; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                24: begin
                    integer i;
                    i = (24-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (24 < 28) state <= 25; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                25: begin
                    integer i;
                    i = (25-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (25 < 28) state <= 26; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                26: begin
                    integer i;
                    i = (26-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (26 < 28) state <= 27; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                27: begin
                    integer i;
                    i = (27-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    if (27 < 28) state <= 28; else state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                28: begin
                    integer i;
                    i = (28-1) % 7;
                    if (value_reg[i] < value_reg[i+1]) begin
                        temp_key = key_reg[i];
                        key_reg[i] = key_reg[i+1];
                        key_reg[i+1] = temp_key;
                        temp_value = value_reg[i];
                        value_reg[i] = value_reg[i+1];
                        value_reg[i+1] = temp_value;
                    end
                    state <= 29;
                    out_key_0 <= 8'b0;
                    out_key_1 <= 8'b0;
                    out_key_2 <= 8'b0;
                    out_key_3 <= 8'b0;
                    out_value_0 <= 16'b0;
                    out_value_1 <= 16'b0;
                    out_value_2 <= 16'b0;
                    out_value_3 <= 16'b0;
                    done <= 0;
                end
                29: begin
                    out_key_0 <= key_reg[0];
                    out_key_1 <= key_reg[1];
                    out_key_2 <= key_reg[2];
                    out_key_3 <= key_reg[3];
                    out_value_0 <= value_reg[0];
                    out_value_1 <= value_reg[1];
                    out_value_2 <= value_reg[2];
                    out_value_3 <= value_reg[3];
                    done <= 1;
                    state <= 29;
                end
            endcase
        end
    end
endmodule