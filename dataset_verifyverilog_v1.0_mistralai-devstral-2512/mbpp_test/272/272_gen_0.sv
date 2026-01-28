module tuple_extractor(
    input wire clk,
    input wire rst_n,
    input wire start,
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
    input wire valid_input,
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

    // State declarations
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] PROCESSING = 4'd1;
    localparam [3:0] DONE_STATE = 4'd2;

    // Internal signals
    reg [3:0] state;
    reg [2:0] counter;
    reg [7:0] temp_result [0:7];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            counter <= 3'd0;
            done <= 1'b0;
            valid_output <= 1'b0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            temp_result[0] <= 8'd0;
            temp_result[1] <= 8'd0;
            temp_result[2] <= 8'd0;
            temp_result[3] <= 8'd0;
            temp_result[4] <= 8'd0;
            temp_result[5] <= 8'd0;
            temp_result[6] <= 8'd0;
            temp_result[7] <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_output <= 1'b0;
                    if (start && valid_input) begin
                        state <= PROCESSING;
                        counter <= 3'd0;
                    end
                end

                PROCESSING: begin
                    // Extract last element from current tuple
                    case (counter)
                        3'd0: temp_result[0] <= tuples_0_el_2;
                        3'd1: temp_result[1] <= tuples_1_el_2;
                        3'd2: temp_result[2] <= tuples_2_el_2;
                        3'd3: temp_result[3] <= tuples_3_el_2;
                        3'd4: temp_result[4] <= tuples_4_el_2;
                        3'd5: temp_result[5] <= tuples_5_el_2;
                        3'd6: temp_result[6] <= tuples_6_el_2;
                        3'd7: temp_result[7] <= tuples_7_el_2;
                        default: ;
                    endcase

                    // Increment counter
                    if (counter == 3'd7) begin
                        counter <= 3'd0;
                        state <= DONE_STATE;
                    end else begin
                        counter <= counter + 3'd1;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    valid_output <= 1'b1;
                    result_0 <= temp_result[0];
                    result_1 <= temp_result[1];
                    result_2 <= temp_result[2];
                    result_3 <= temp_result[3];
                    result_4 <= temp_result[4];
                    result_5 <= temp_result[5];
                    result_6 <= temp_result[6];
                    result_7 <= temp_result[7];
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    valid_output <= 1'b0;
                end
            endcase
        end
    end
endmodule