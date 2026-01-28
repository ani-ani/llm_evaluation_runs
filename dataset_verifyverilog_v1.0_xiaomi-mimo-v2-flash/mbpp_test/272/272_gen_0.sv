module extract_last_element (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire valid_input,
    input wire [7:0] tuples_0_el_0,
    input wire [7:0] tuples_0_el_1,
    input wire [7:0] tuples_0_el_2,
    input wire [7:0] tuples_1_el_0,
    input wire [7:0] tuples_1_el_1,
    input wire [7:0] tuples_1_el_2,
    input wire [7:0] tuples_2_el_0,
    input wire [7:0] tuples_2_el_1,
    input wire [7:0] tuples_2_el_2,
    input wire [7:0] tuples_3_el_0,
    input wire [7:0] tuples_3_el_1,
    input wire [7:0] tuples_3_el_2,
    input wire [7:0] tuples_4_el_0,
    input wire [7:0] tuples_4_el_1,
    input wire [7:0] tuples_4_el_2,
    input wire [7:0] tuples_5_el_0,
    input wire [7:0] tuples_5_el_1,
    input wire [7:0] tuples_5_el_2,
    input wire [7:0] tuples_6_el_0,
    input wire [7:0] tuples_6_el_1,
    input wire [7:0] tuples_6_el_2,
    input wire [7:0] tuples_7_el_0,
    input wire [7:0] tuples_7_el_1,
    input wire [7:0] tuples_7_el_2,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done,
    output reg valid_output
);

    // State definitions
    localparam [3:0] STATE_IDLE      = 4'd0;
    localparam [3:0] STATE_PROCESS   = 4'd1;
    localparam [3:0] STATE_DONE      = 4'd2;

    // Internal registers
    reg [3:0] state, next_state;
    reg [2:0] counter, next_counter;
    reg [7:0] temp_result_0, temp_result_1, temp_result_2, temp_result_3;
    reg [7:0] temp_result_4, temp_result_5, temp_result_6, temp_result_7;
    reg [7:0] next_temp_result_0, next_temp_result_1, next_temp_result_2, next_temp_result_3;
    reg [7:0] next_temp_result_4, next_temp_result_5, next_temp_result_6, next_temp_result_7;
    reg next_done, next_valid_output;
    reg [7:0] next_result_0, next_result_1, next_result_2, next_result_3;
    reg [7:0] next_result_4, next_result_5, next_result_6, next_result_7;

    // Combinational next state logic
    always @(*) begin
        // Default values
        next_state = state;
        next_counter = counter;
        next_done = 1'b0;
        next_valid_output = 1'b0;
        next_temp_result_0 = temp_result_0;
        next_temp_result_1 = temp_result_1;
        next_temp_result_2 = temp_result_2;
        next_temp_result_3 = temp_result_3;
        next_temp_result_4 = temp_result_4;
        next_temp_result_5 = temp_result_5;
        next_temp_result_6 = temp_result_6;
        next_temp_result_7 = temp_result_7;
        next_result_0 = result_0;
        next_result_1 = result_1;
        next_result_2 = result_2;
        next_result_3 = result_3;
        next_result_4 = result_4;
        next_result_5 = result_5;
        next_result_6 = result_6;
        next_result_7 = result_7;

        case (state)
            STATE_IDLE: begin
                next_counter = 3'd0;
                next_done = 1'b0;
                next_valid_output = 1'b0;
                if (start && valid_input) begin
                    next_state = STATE_PROCESS;
                end
            end

            STATE_PROCESS: begin
                case (counter)
                    3'd0: next_temp_result_0 = tuples_0_el_2;
                    3'd1: next_temp_result_1 = tuples_1_el_2;
                    3'd2: next_temp_result_2 = tuples_2_el_2;
                    3'd3: next_temp_result_3 = tuples_3_el_2;
                    3'd4: next_temp_result_4 = tuples_4_el_2;
                    3'd5: next_temp_result_5 = tuples_5_el_2;
                    3'd6: next_temp_result_6 = tuples_6_el_2;
                    3'd7: next_temp_result_7 = tuples_7_el_2;
                    default: begin
                        next_temp_result_0 = 8'd0;
                        next_temp_result_1 = 8'd0;
                        next_temp_result_2 = 8'd0;
                        next_temp_result_3 = 8'd0;
                        next_temp_result_4 = 8'd0;
                        next_temp_result_5 = 8'd0;
                        next_temp_result_6 = 8'd0;
                        next_temp_result_7 = 8'd0;
                    end
                endcase

                if (counter == 3'd7) begin
                    next_state = STATE_DONE;
                end else begin
                    next_counter = counter + 3'd1;
                end
            end

            STATE_DONE: begin
                next_done = 1'b1;
                next_valid_output = 1'b1;
                next_result_0 = temp_result_0;
                next_result_1 = temp_result_1;
                next_result_2 = temp_result_2;
                next_result_3 = temp_result_3;
                next_result_4 = temp_result_4;
                next_result_5 = temp_result_5;
                next_result_6 = temp_result_6;
                next_result_7 = temp_result_7;
                next_state = STATE_IDLE;
            end

            default: begin
                next_state = STATE_IDLE;
            end
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            counter <= 3'd0;
            done <= 1'b0;
            valid_output <= 1'b0;
            temp_result_0 <= 8'd0;
            temp_result_1 <= 8'd0;
            temp_result_2 <= 8'd0;
            temp_result_3 <= 8'd0;
            temp_result_4 <= 8'd0;
            temp_result_5 <= 8'd0;
            temp_result_6 <= 8'd0;
            temp_result_7 <= 8'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
        end else begin
            state <= next_state;
            counter <= next_counter;
            done <= next_done;
            valid_output <= next_valid_output;
            temp_result_0 <= next_temp_result_0;
            temp_result_1 <= next_temp_result_1;
            temp_result_2 <= next_temp_result_2;
            temp_result_3 <= next_temp_result_3;
            temp_result_4 <= next_temp_result_4;
            temp_result_5 <= next_temp_result_5;
            temp_result_6 <= next_temp_result_6;
            temp_result_7 <= next_temp_result_7;
            result_0 <= next_result_0;
            result_1 <= next_result_1;
            result_2 <= next_result_2;
            result_3 <= next_result_3;
            result_4 <= next_result_4;
            result_5 <= next_result_5;
            result_6 <= next_result_6;
            result_7 <= next_result_7;
        end
    end

endmodule