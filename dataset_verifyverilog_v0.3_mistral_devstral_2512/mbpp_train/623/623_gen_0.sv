module power_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [4:0] exponent,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    output reg [31:0] result_0,
    output reg [31:0] result_1,
    output reg [31:0] result_2,
    output reg [31:0] result_3,
    output reg [31:0] result_4,
    output reg [31:0] result_5,
    output reg [31:0] result_6,
    output reg [31:0] result_7,
    output reg done
);

    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] LOAD      = 3'd1;
    localparam [2:0] COMPUTE   = 3'd2;
    localparam [2:0] STORE     = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    localparam [2:0] ARRAY_SIZE = 3'd8;
    localparam [4:0] DATA_WIDTH = 5'd8;
    localparam [4:0] RESULT_WIDTH = 5'd32;
    localparam [4:0] EXP_WIDTH = 5'd5;

    reg [2:0] state, next_state;
    reg [2:0] index;
    reg [4:0] exp_counter;
    reg [31:0] current_value;
    reg [31:0] current_result;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            exp_counter <= 5'd0;
            current_value <= 32'd0;
            current_result <= 32'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
            result_0 <= 32'd0;
            result_1 <= 32'd0;
            result_2 <= 32'd0;
            result_3 <= 32'd0;
            result_4 <= 32'd0;
            result_5 <= 32'd0;
            result_6 <= 32'd0;
            result_7 <= 32'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOAD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOAD: begin
                    case (index)
                        3'd0: current_value <= arr_0;
                        3'd1: current_value <= arr_1;
                        3'd2: current_value <= arr_2;
                        3'd3: current_value <= arr_3;
                        3'd4: current_value <= arr_4;
                        3'd5: current_value <= arr_5;
                        3'd6: current_value <= arr_6;
                        3'd7: current_value <= arr_7;
                        default: current_value <= 32'd0;
                    endcase
                    if (exponent == 5'd0) begin
                        current_result <= 32'd1;
                        next_state <= STORE;
                    end else begin
                        current_result <= current_value;
                        exp_counter <= exponent - 5'd1;
                        next_state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (exp_counter > 5'd0) begin
                        current_result <= current_result * current_value;
                        exp_counter <= exp_counter - 5'd1;
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= STORE;
                    end
                end

                STORE: begin
                    case (index)
                        3'd0: result_0 <= current_result;
                        3'd1: result_1 <= current_result;
                        3'd2: result_2 <= current_result;
                        3'd3: result_3 <= current_result;
                        3'd4: result_4 <= current_result;
                        3'd5: result_5 <= current_result;
                        3'd6: result_6 <= current_result;
                        3'd7: result_7 <= current_result;
                        default: ;
                    endcase
                    if (index == ARRAY_SIZE - 3'd1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        index <= index + 3'd1;
                        next_state <= LOAD;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule