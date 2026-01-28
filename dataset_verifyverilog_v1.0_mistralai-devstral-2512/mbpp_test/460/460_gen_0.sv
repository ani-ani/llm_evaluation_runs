module extract_first_elements(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] sublist_0_element_0,
    input wire [7:0] sublist_0_element_1,
    input wire [7:0] sublist_0_element_2,
    input wire [7:0] sublist_0_element_3,
    input wire [7:0] sublist_1_element_0,
    input wire [7:0] sublist_1_element_1,
    input wire [7:0] sublist_1_element_2,
    input wire [7:0] sublist_1_element_3,
    input wire [7:0] sublist_2_element_0,
    input wire [7:0] sublist_2_element_1,
    input wire [7:0] sublist_2_element_2,
    input wire [7:0] sublist_2_element_3,
    input wire [7:0] sublist_3_element_0,
    input wire [7:0] sublist_3_element_1,
    input wire [7:0] sublist_3_element_2,
    input wire [7:0] sublist_3_element_3,
    input wire [7:0] sublist_4_element_0,
    input wire [7:0] sublist_4_element_1,
    input wire [7:0] sublist_4_element_2,
    input wire [7:0] sublist_4_element_3,
    input wire [7:0] sublist_5_element_0,
    input wire [7:0] sublist_5_element_1,
    input wire [7:0] sublist_5_element_2,
    input wire [7:0] sublist_5_element_3,
    input wire [7:0] sublist_6_element_0,
    input wire [7:0] sublist_6_element_1,
    input wire [7:0] sublist_6_element_2,
    input wire [7:0] sublist_6_element_3,
    input wire [7:0] sublist_7_element_0,
    input wire [7:0] sublist_7_element_1,
    input wire [7:0] sublist_7_element_2,
    input wire [7:0] sublist_7_element_3,
    input wire [2:0] num_sublists,
    input wire [3:0] sublist_0_length,
    input wire [3:0] sublist_1_length,
    input wire [3:0] sublist_2_length,
    input wire [3:0] sublist_3_length,
    input wire [3:0] sublist_4_length,
    input wire [3:0] sublist_5_length,
    input wire [3:0] sublist_6_length,
    input wire [3:0] sublist_7_length,
    output reg [7:0] result_0,
    output reg [7:0] result_1,
    output reg [7:0] result_2,
    output reg [7:0] result_3,
    output reg [7:0] result_4,
    output reg [7:0] result_5,
    output reg [7:0] result_6,
    output reg [7:0] result_7,
    output reg done
);

    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    reg [1:0] state, next_state;
    reg [2:0] current_sublist;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            current_sublist <= 3'd0;
            cycle_count <= 8'd0;
            done <= 1'b0;
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
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= PROCESSING;
                        current_sublist <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (current_sublist < num_sublists) begin
                        case (current_sublist)
                            3'd0: begin
                                if (sublist_0_length > 4'd0) begin
                                    result_0 <= sublist_0_element_0;
                                end else begin
                                    result_0 <= 8'd0;
                                end
                            end
                            3'd1: begin
                                if (sublist_1_length > 4'd0) begin
                                    result_1 <= sublist_1_element_0;
                                end else begin
                                    result_1 <= 8'd0;
                                end
                            end
                            3'd2: begin
                                if (sublist_2_length > 4'd0) begin
                                    result_2 <= sublist_2_element_0;
                                end else begin
                                    result_2 <= 8'd0;
                                end
                            end
                            3'd3: begin
                                if (sublist_3_length > 4'd0) begin
                                    result_3 <= sublist_3_element_0;
                                end else begin
                                    result_3 <= 8'd0;
                                end
                            end
                            3'd4: begin
                                if (sublist_4_length > 4'd0) begin
                                    result_4 <= sublist_4_element_0;
                                end else begin
                                    result_4 <= 8'd0;
                                end
                            end
                            3'd5: begin
                                if (sublist_5_length > 4'd0) begin
                                    result_5 <= sublist_5_element_0;
                                end else begin
                                    result_5 <= 8'd0;
                                end
                            end
                            3'd6: begin
                                if (sublist_6_length > 4'd0) begin
                                    result_6 <= sublist_6_element_0;
                                end else begin
                                    result_6 <= 8'd0;
                                end
                            end
                            3'd7: begin
                                if (sublist_7_length > 4'd0) begin
                                    result_7 <= sublist_7_element_0;
                                end else begin
                                    result_7 <= 8'd0;
                                end
                            end
                        endcase
                        current_sublist <= current_sublist + 3'd1;
                        if (current_sublist == num_sublists || cycle_count >= MAX_CYCLES) begin
                            next_state <= DONE_STATE;
                        end else begin
                            next_state <= PROCESSING;
                        end
                    end else begin
                        next_state <= DONE_STATE;
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