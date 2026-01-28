module tuple_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire signed [15:0] arr_0,
    input wire signed [15:0] arr_1,
    input wire signed [15:0] arr_2,
    input wire signed [15:0] arr_3,
    input wire signed [15:0] arr_4,
    input wire signed [15:0] arr_5,
    input wire signed [15:0] arr_6,
    input wire signed [15:0] arr_7,
    input wire signed [15:0] arr_8,
    input wire signed [15:0] arr_9,
    input wire signed [15:0] arr_10,
    input wire signed [15:0] arr_11,
    input wire signed [15:0] arr_12,
    input wire signed [15:0] arr_13,
    input wire signed [15:0] arr_14,
    input wire signed [15:0] arr_15,
    output reg [3:0] result,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] SCAN = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    localparam [3:0] MAX_LEN = 4'd16;
    localparam signed [15:0] TUPLE_VAL_A = 16'sd4;
    localparam signed [15:0] TUPLE_VAL_B = 16'sd6;

    reg [1:0] state, next_state;
    reg [3:0] idx;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                done = 1'b0;
                if (start) begin
                    next_state = SCAN;
                    idx = 4'd0;
                    cycle_count = 8'd0;
                end
            end
            
            SCAN: begin
                if (idx < len) begin
                    if (arr_0 == TUPLE_VAL_A && idx == 4'd0 && len > 4'd1 && arr_1 == TUPLE_VAL_B) begin
                        result = 4'd0;
                        next_state = FINISH;
                    end else if (arr_1 == TUPLE_VAL_A && idx == 4'd1 && len > 4'd2 && arr_2 == TUPLE_VAL_B) begin
                        result = 4'd1;
                        next_state = FINISH;
                    end else if (arr_2 == TUPLE_VAL_A && idx == 4'd2 && len > 4'd3 && arr_3 == TUPLE_VAL_B) begin
                        result = 4'd2;
                        next_state = FINISH;
                    end else if (arr_3 == TUPLE_VAL_A && idx == 4'd3 && len > 4'd4 && arr_4 == TUPLE_VAL_B) begin
                        result = 4'd3;
                        next_state = FINISH;
                    end else if (arr_4 == TUPLE_VAL_A && idx == 4'd4 && len > 4'd5 && arr_5 == TUPLE_VAL_B) begin
                        result = 4'd4;
                        next_state = FINISH;
                    end else if (arr_5 == TUPLE_VAL_A && idx == 4'd5 && len > 4'd6 && arr_6 == TUPLE_VAL_B) begin
                        result = 4'd5;
                        next_state = FINISH;
                    end else if (arr_6 == TUPLE_VAL_A && idx == 4'd6 && len > 4'd7 && arr_7 == TUPLE_VAL_B) begin
                        result = 4'd6;
                        next_state = FINISH;
                    end else if (arr_7 == TUPLE_VAL_A && idx == 4'd7 && len > 4'd8 && arr_8 == TUPLE_VAL_B) begin
                        result = 4'd7;
                        next_state = FINISH;
                    end else if (arr_8 == TUPLE_VAL_A && idx == 4'd8 && len > 4'd9 && arr_9 == TUPLE_VAL_B) begin
                        result = 4'd8;
                        next_state = FINISH;
                    end else if (arr_9 == TUPLE_VAL_A && idx == 4'd9 && len > 4'd10 && arr_10 == TUPLE_VAL_B) begin
                        result = 4'd9;
                        next_state = FINISH;
                    end else if (arr_10 == TUPLE_VAL_A && idx == 4'd10 && len > 4'd11 && arr_11 == TUPLE_VAL_B) begin
                        result = 4'd10;
                        next_state = FINISH;
                    end else if (arr_11 == TUPLE_VAL_A && idx == 4'd11 && len > 4'd12 && arr_12 == TUPLE_VAL_B) begin
                        result = 4'd11;
                        next_state = FINISH;
                    end else if (arr_12 == TUPLE_VAL_A && idx == 4'd12 && len > 4'd13 && arr_13 == TUPLE_VAL_B) begin
                        result = 4'd12;
                        next_state = FINISH;
                    end else if (arr_13 == TUPLE_VAL_A && idx == 4'd13 && len > 4'd14 && arr_14 == TUPLE_VAL_B) begin
                        result = 4'd13;
                        next_state = FINISH;
                    end else if (arr_14 == TUPLE_VAL_A && idx == 4'd14 && len > 4'd15 && arr_15 == TUPLE_VAL_B) begin
                        result = 4'd14;
                        next_state = FINISH;
                    end else begin
                        idx = idx + 4'd1;
                        cycle_count = cycle_count + 8'd1;
                        if (idx >= len || cycle_count >= MAX_CYCLES) begin
                            result = len;
                            next_state = FINISH;
                        end
                    end
                end else begin
                    result = len;
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                done = 1'b1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule