module ExtractFirstElements (
    input clk,
    input rst_n,
    input start,
    // 8 sublists, each with 4 elements (32 total inputs)
    input [7:0] sublist_0_element_0,
    input [7:0] sublist_0_element_1,
    input [7:0] sublist_0_element_2,
    input [7:0] sublist_0_element_3,
    input [7:0] sublist_1_element_0,
    input [7:0] sublist_1_element_1,
    input [7:0] sublist_1_element_2,
    input [7:0] sublist_1_element_3,
    input [7:0] sublist_2_element_0,
    input [7:0] sublist_2_element_1,
    input [7:0] sublist_2_element_2,
    input [7:0] sublist_2_element_3,
    input [7:0] sublist_3_element_0,
    input [7:0] sublist_3_element_1,
    input [7:0] sublist_3_element_2,
    input [7:0] sublist_3_element_3,
    input [7:0] sublist_4_element_0,
    input [7:0] sublist_4_element_1,
    input [7:0] sublist_4_element_2,
    input [7:0] sublist_4_element_3,
    input [7:0] sublist_5_element_0,
    input [7:0] sublist_5_element_1,
    input [7:0] sublist_5_element_2,
    input [7:0] sublist_5_element_3,
    input [7:0] sublist_6_element_0,
    input [7:0] sublist_6_element_1,
    input [7:0] sublist_6_element_2,
    input [7:0] sublist_6_element_3,
    input [7:0] sublist_7_element_0,
    input [7:0] sublist_7_element_1,
    input [7:0] sublist_7_element_2,
    input [7:0] sublist_7_element_3,
    input [2:0] num_sublists,
    input [3:0] sublist_lengths_0,
    input [3:0] sublist_lengths_1,
    input [3:0] sublist_lengths_2,
    input [3:0] sublist_lengths_3,
    input [3:0] sublist_lengths_4,
    input [3:0] sublist_lengths_5,
    input [3:0] sublist_lengths_6,
    input [3:0] sublist_lengths_7,
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

    // State declarations
    localparam [1:0] IDLE       = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [2:0] sublist_index;  // 0-7 for 8 sublists
    reg [7:0] cycle_count;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Helper array for lengths (flattened from inputs)
    reg [3:0] sublist_length [0:7];

    // Combinational logic to select first element
    wire [7:0] first_element [0:7];
    assign first_element[0] = sublist_0_element_0;
    assign first_element[1] = sublist_1_element_0;
    assign first_element[2] = sublist_2_element_0;
    assign first_element[3] = sublist_3_element_0;
    assign first_element[4] = sublist_4_element_0;
    assign first_element[5] = sublist_5_element_0;
    assign first_element[6] = sublist_6_element_0;
    assign first_element[7] = sublist_7_element_0;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            done <= 1'b0;
            sublist_index <= 3'd0;
            cycle_count <= 8'd0;
            result_0 <= 8'd0;
            result_1 <= 8'd0;
            result_2 <= 8'd0;
            result_3 <= 8'd0;
            result_4 <= 8'd0;
            result_5 <= 8'd0;
            result_6 <= 8'd0;
            result_7 <= 8'd0;
            // Initialize length array
            sublist_length[0] <= 4'd0;
            sublist_length[1] <= 4'd0;
            sublist_length[2] <= 4'd0;
            sublist_length[3] <= 4'd0;
            sublist_length[4] <= 4'd0;
            sublist_length[5] <= 4'd0;
            sublist_length[6] <= 4'd0;
            sublist_length[7] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Load all lengths into register array
                        sublist_length[0] <= sublist_lengths_0;
                        sublist_length[1] <= sublist_lengths_1;
                        sublist_length[2] <= sublist_lengths_2;
                        sublist_length[3] <= sublist_lengths_3;
                        sublist_length[4] <= sublist_lengths_4;
                        sublist_length[5] <= sublist_lengths_5;
                        sublist_length[6] <= sublist_lengths_6;
                        sublist_length[7] <= sublist_lengths_7;
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Process current sublist
                    if (sublist_index < 3'd8) begin
                        // Check if this sublist is valid (index < num_sublists)
                        if (sublist_index < num_sublists) begin
                            // Check if sublist has at least one element
                            if (sublist_length[sublist_index] > 4'd0) begin
                                // Extract first element (always at index 0)
                                case (sublist_index)
                                    3'd0: result_0 <= first_element[0];
                                    3'd1: result_1 <= first_element[1];
                                    3'd2: result_2 <= first_element[2];
                                    3'd3: result_3 <= first_element[3];
                                    3'd4: result_4 <= first_element[4];
                                    3'd5: result_5 <= first_element[5];
                                    3'd6: result_6 <= first_element[6];
                                    3'd7: result_7 <= first_element[7];
                                endcase
                            end else begin
                                // Length is 0, output 0
                                case (sublist_index)
                                    3'd0: result_0 <= 8'd0;
                                    3'd1: result_1 <= 8'd0;
                                    3'd2: result_2 <= 8'd0;
                                    3'd3: result_3 <= 8'd0;
                                    3'd4: result_4 <= 8'd0;
                                    3'd5: result_5 <= 8'd0;
                                    3'd6: result_6 <= 8'd0;
                                    3'd7: result_7 <= 8'd0;
                                endcase
                            end
                        end else begin
                            // Invalid sublist (index >= num_sublists), output 0
                            case (sublist_index)
                                3'd0: result_0 <= 8'd0;
                                3'd1: result_1 <= 8'd0;
                                3'd2: result_2 <= 8'd0;
                                3'd3: result_3 <= 8'd0;
                                3'd4: result_4 <= 8'd0;
                                3'd5: result_5 <= 8'd0;
                                3'd6: result_6 <= 8'd0;
                                3'd7: result_7 <= 8'd0;
                            endcase
                        end
                        
                        // Move to next sublist
                        if (sublist_index < 3'd7) begin
                            sublist_index <= sublist_index + 3'd1;
                        end else begin
                            // Done with all sublists
                            state <= DONE_STATE;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                    sublist_index <= 3'd0;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                    sublist_index <= 3'd0;
                    cycle_count <= 8'd0;
                end
            endcase
        end
    end

endmodule