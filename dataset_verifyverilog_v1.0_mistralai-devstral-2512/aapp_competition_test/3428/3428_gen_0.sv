module GcdCounter(
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
    input [7:0] arr_8,
    input [7:0] arr_9,
    input [7:0] arr_10,
    input [7:0] arr_11,
    input [7:0] arr_12,
    input [7:0] arr_13,
    input [7:0] arr_14,
    input [7:0] arr_15,
    input [3:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] CALCULATING = 3'd1;
    localparam [2:0] COUNTING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Registers
    reg [2:0] state, next_state;
    reg [7:0] i_reg, j_reg;
    reg [7:0] current_gcd;
    reg [255:0] gcd_set;
    reg [7:0] distinct_count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Array selection
    wire [7:0] arr [0:15];
    assign arr[0] = arr_0;
    assign arr[1] = arr_1;
    assign arr[2] = arr_2;
    assign arr[3] = arr_3;
    assign arr[4] = arr_4;
    assign arr[5] = arr_5;
    assign arr[6] = arr_6;
    assign arr[7] = arr_7;
    assign arr[8] = arr_8;
    assign arr[9] = arr_9;
    assign arr[10] = arr_10;
    assign arr[11] = arr_11;
    assign arr[12] = arr_12;
    assign arr[13] = arr_13;
    assign arr[14] = arr_14;
    assign arr[15] = arr_15;

    // GCD calculation function
    function [7:0] gcd_func;
        input [7:0] a, b;
        reg [7:0] x, y, temp;
        begin
            x = a;
            y = b;
            while (y != 0) begin
                temp = y;
                y = x % y;
                x = temp;
            end
            gcd_func = x;
        end
    endfunction

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            i_reg <= 8'd0;
            j_reg <= 8'd0;
            current_gcd <= 8'd0;
            distinct_count <= 8'd0;
            cycle_count <= 8'd0;
            gcd_set <= 256'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CALCULATING;
                end
            end

            CALCULATING: begin
                if (cycle_count >= MAX_CYCLES) begin
                    next_state = COUNTING;
                end else if (i_reg == len - 1 && j_reg == len - 1) begin
                    next_state = COUNTING;
                end
            end

            COUNTING: begin
                next_state = DONE_STATE;
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Already handled in state machine
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    i_reg <= 8'd0;
                    j_reg <= 8'd0;
                    current_gcd <= 8'd0;
                    gcd_set <= 256'd0;
                end

                CALCULATING: begin
                    cycle_count <= cycle_count + 8'd1;

                    if (j_reg == len - 1) begin
                        i_reg <= i_reg + 8'd1;
                        j_reg <= i_reg;
                        current_gcd <= 8'd0;
                    end else begin
                        j_reg <= j_reg + 8'd1;
                    end

                    if (j_reg <= len - 1) begin
                        current_gcd <= gcd_func(current_gcd, arr[j_reg]);
                        gcd_set[current_gcd] <= 1'b1;
                    end
                end

                COUNTING: begin
                    distinct_count <= 0;
                    for (integer k = 0; k < 256; k = k + 1) begin
                        if (gcd_set[k]) begin
                            distinct_count <= distinct_count + 8'd1;
                        end
                    end
                end

                DONE_STATE: begin
                    result <= distinct_count;
                    done <= 1'b1;
                end

                default: begin
                    done <= 1'b0;
                    result <= 8'd0;
                end
            endcase
        end
    end

endmodule