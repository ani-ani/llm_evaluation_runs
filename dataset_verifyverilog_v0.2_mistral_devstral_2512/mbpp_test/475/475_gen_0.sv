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

    // Internal registers for sorting
    reg [7:0] key_reg [0:7];
    reg [15:0] value_reg [0:7];

    // State machine
    typedef enum logic [4:0] {
        IDLE,
        SORT_1, SORT_2, SORT_3, SORT_4, SORT_5, SORT_6, SORT_7,
        SORT_8, SORT_9, SORT_10, SORT_11, SORT_12, SORT_13, SORT_14,
        SORT_15, SORT_16, SORT_17, SORT_18, SORT_19, SORT_20, SORT_21,
        SORT_22, SORT_23, SORT_24, SORT_25, SORT_26, SORT_27, SORT_28,
        DONE
    } state;

    // State register
    reg [4:0] state_reg;

    // Initialize outputs
    initial begin
        out_key_0 = 0;
        out_key_1 = 0;
        out_key_2 = 0;
        out_key_3 = 0;
        out_value_0 = 0;
        out_value_1 = 0;
        out_value_2 = 0;
        out_value_3 = 0;
        done = 0;
    end

    // State machine logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            done <= 0;
        end else begin
            case (state_reg)
                IDLE: begin
                    if (start) begin
                        state_reg <= SORT_1;
                        // Load initial values
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
                    end
                end
                SORT_1: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_2;
                end
                SORT_2: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_3;
                end
                SORT_3: begin
                    if (value_reg[2] < value_reg[3]) begin
                        {key_reg[2], key_reg[3]} <= {key_reg[3], key_reg[2]};
                        {value_reg[2], value_reg[3]} <= {value_reg[3], value_reg[2]};
                    end
                    state_reg <= SORT_4;
                end
                SORT_4: begin
                    if (value_reg[3] < value_reg[4]) begin
                        {key_reg[3], key_reg[4]} <= {key_reg[4], key_reg[3]};
                        {value_reg[3], value_reg[4]} <= {value_reg[4], value_reg[3]};
                    end
                    state_reg <= SORT_5;
                end
                SORT_5: begin
                    if (value_reg[4] < value_reg[5]) begin
                        {key_reg[4], key_reg[5]} <= {key_reg[5], key_reg[4]};
                        {value_reg[4], value_reg[5]} <= {value_reg[5], value_reg[4]};
                    end
                    state_reg <= SORT_6;
                end
                SORT_6: begin
                    if (value_reg[5] < value_reg[6]) begin
                        {key_reg[5], key_reg[6]} <= {key_reg[6], key_reg[5]};
                        {value_reg[5], value_reg[6]} <= {value_reg[6], value_reg[5]};
                    end
                    state_reg <= SORT_7;
                end
                SORT_7: begin
                    if (value_reg[6] < value_reg[7]) begin
                        {key_reg[6], key_reg[7]} <= {key_reg[7], key_reg[6]};
                        {value_reg[6], value_reg[7]} <= {value_reg[7], value_reg[6]};
                    end
                    state_reg <= SORT_8;
                end
                SORT_8: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_9;
                end
                SORT_9: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_10;
                end
                SORT_10: begin
                    if (value_reg[2] < value_reg[3]) begin
                        {key_reg[2], key_reg[3]} <= {key_reg[3], key_reg[2]};
                        {value_reg[2], value_reg[3]} <= {value_reg[3], value_reg[2]};
                    end
                    state_reg <= SORT_11;
                end
                SORT_11: begin
                    if (value_reg[3] < value_reg[4]) begin
                        {key_reg[3], key_reg[4]} <= {key_reg[4], key_reg[3]};
                        {value_reg[3], value_reg[4]} <= {value_reg[4], value_reg[3]};
                    end
                    state_reg <= SORT_12;
                end
                SORT_12: begin
                    if (value_reg[4] < value_reg[5]) begin
                        {key_reg[4], key_reg[5]} <= {key_reg[5], key_reg[4]};
                        {value_reg[4], value_reg[5]} <= {value_reg[5], value_reg[4]};
                    end
                    state_reg <= SORT_13;
                end
                SORT_13: begin
                    if (value_reg[5] < value_reg[6]) begin
                        {key_reg[5], key_reg[6]} <= {key_reg[6], key_reg[5]};
                        {value_reg[5], value_reg[6]} <= {value_reg[6], value_reg[5]};
                    end
                    state_reg <= SORT_14;
                end
                SORT_14: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_15;
                end
                SORT_15: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_16;
                end
                SORT_16: begin
                    if (value_reg[2] < value_reg[3]) begin
                        {key_reg[2], key_reg[3]} <= {key_reg[3], key_reg[2]};
                        {value_reg[2], value_reg[3]} <= {value_reg[3], value_reg[2]};
                    end
                    state_reg <= SORT_17;
                end
                SORT_17: begin
                    if (value_reg[3] < value_reg[4]) begin
                        {key_reg[3], key_reg[4]} <= {key_reg[4], key_reg[3]};
                        {value_reg[3], value_reg[4]} <= {value_reg[4], value_reg[3]};
                    end
                    state_reg <= SORT_18;
                end
                SORT_18: begin
                    if (value_reg[4] < value_reg[5]) begin
                        {key_reg[4], key_reg[5]} <= {key_reg[5], key_reg[4]};
                        {value_reg[4], value_reg[5]} <= {value_reg[5], value_reg[4]};
                    end
                    state_reg <= SORT_19;
                end
                SORT_19: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_20;
                end
                SORT_20: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_21;
                end
                SORT_21: begin
                    if (value_reg[2] < value_reg[3]) begin
                        {key_reg[2], key_reg[3]} <= {key_reg[3], key_reg[2]};
                        {value_reg[2], value_reg[3]} <= {value_reg[3], value_reg[2]};
                    end
                    state_reg <= SORT_22;
                end
                SORT_22: begin
                    if (value_reg[3] < value_reg[4]) begin
                        {key_reg[3], key_reg[4]} <= {key_reg[4], key_reg[3]};
                        {value_reg[3], value_reg[4]} <= {value_reg[4], value_reg[3]};
                    end
                    state_reg <= SORT_23;
                end
                SORT_23: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_24;
                end
                SORT_24: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_25;
                end
                SORT_25: begin
                    if (value_reg[2] < value_reg[3]) begin
                        {key_reg[2], key_reg[3]} <= {key_reg[3], key_reg[2]};
                        {value_reg[2], value_reg[3]} <= {value_reg[3], value_reg[2]};
                    end
                    state_reg <= SORT_26;
                end
                SORT_26: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= SORT_27;
                end
                SORT_27: begin
                    if (value_reg[1] < value_reg[2]) begin
                        {key_reg[1], key_reg[2]} <= {key_reg[2], key_reg[1]};
                        {value_reg[1], value_reg[2]} <= {value_reg[2], value_reg[1]};
                    end
                    state_reg <= SORT_28;
                end
                SORT_28: begin
                    if (value_reg[0] < value_reg[1]) begin
                        {key_reg[0], key_reg[1]} <= {key_reg[1], key_reg[0]};
                        {value_reg[0], value_reg[1]} <= {value_reg[1], value_reg[0]};
                    end
                    state_reg <= DONE;
                end
                DONE: begin
                    // Output top 4 sorted entries
                    out_key_0 <= key_reg[0];
                    out_key_1 <= key_reg[1];
                    out_key_2 <= key_reg[2];
                    out_key_3 <= key_reg[3];
                    out_value_0 <= value_reg[0];
                    out_value_1 <= value_reg[1];
                    out_value_2 <= value_reg[2];
                    out_value_3 <= value_reg[3];
                    done <= 1;
                end
                default: state_reg <= IDLE;
            endcase
        end
    end

endmodule