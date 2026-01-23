module extract_index_list (
    // Inputs
    input wire clk,           // Clock signal
    input wire rst_n,         // Active-low reset
    input wire start,         // Start pulse (assert for 1 cycle)
    
    // Input arrays - 8 elements each, 8 bits wide
    input wire [7:0] l1_0, l1_1, l1_2, l1_3, l1_4, l1_5, l1_6, l1_7,
    input wire [7:0] l2_0, l2_1, l2_2, l2_3, l2_4, l2_5, l2_6, l2_7,
    input wire [7:0] l3_0, l3_1, l3_2, l3_3, l3_4, l3_5, l3_6, l3_7,
    
    // Outputs
    output reg [7:0] result_0, result_1, result_2, result_3, result_4, result_5, result_6, result_7,
    output reg [3:0] result_count,  // Number of common elements found
    output reg done                 // Asserted high when computation complete
);

    // Internal state machine
    reg [2:0] state;
    reg [3:0] idx;
    
    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] OUTPUT = 3'd2;
    localparam [2:0] FINISHED = 3'd3;
    
    // Temporary storage during comparison
    reg [7:0] temp_result_0, temp_result_1, temp_result_2, temp_result_3;
    reg [7:0] temp_result_4, temp_result_5, temp_result_6, temp_result_7;
    reg [3:0] temp_count;
    
    // Comparison results for each index
    wire match_0, match_1, match_2, match_3;
    wire match_4, match_5, match_6, match_7;
    
    assign match_0 = (l1_0 == l2_0) && (l2_0 == l3_0);
    assign match_1 = (l1_1 == l2_1) && (l2_1 == l3_1);
    assign match_2 = (l1_2 == l2_2) && (l2_2 == l3_2);
    assign match_3 = (l1_3 == l2_3) && (l2_3 == l3_3);
    assign match_4 = (l1_4 == l2_4) && (l2_4 == l3_4);
    assign match_5 = (l1_5 == l2_5) && (l2_5 == l3_5);
    assign match_6 = (l1_6 == l2_6) && (l2_6 == l3_6);
    assign match_7 = (l1_7 == l2_7) && (l2_7 == l3_7);
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all signals
            state <= IDLE;
            done <= 1'b0;
            result_count <= 4'd0;
            result_0 <= 8'd0; result_1 <= 8'd0; result_2 <= 8'd0; result_3 <= 8'd0;
            result_4 <= 8'd0; result_5 <= 8'd0; result_6 <= 8'd0; result_7 <= 8'd0;
            idx <= 4'd0;
            temp_count <= 4'd0;
            temp_result_0 <= 8'd0; temp_result_1 <= 8'd0; temp_result_2 <= 8'd0; temp_result_3 <= 8'd0;
            temp_result_4 <= 8'd0; temp_result_5 <= 8'd0; temp_result_6 <= 8'd0; temp_result_7 <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPARE;
                        idx <= 4'd0;
                        temp_count <= 4'd0;
                    end
                end
                
                COMPARE: begin
                    // Process matches based on current index
                    case (idx)
                        4'd0: begin
                            if (match_0) begin
                                temp_result_0 <= l1_0;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd1;
                        end
                        4'd1: begin
                            if (match_1) begin
                                temp_result_1 <= l1_1;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd2;
                        end
                        4'd2: begin
                            if (match_2) begin
                                temp_result_2 <= l1_2;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd3;
                        end
                        4'd3: begin
                            if (match_3) begin
                                temp_result_3 <= l1_3;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd4;
                        end
                        4'd4: begin
                            if (match_4) begin
                                temp_result_4 <= l1_4;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd5;
                        end
                        4'd5: begin
                            if (match_5) begin
                                temp_result_5 <= l1_5;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd6;
                        end
                        4'd6: begin
                            if (match_6) begin
                                temp_result_6 <= l1_6;
                                temp_count <= temp_count + 1'b1;
                            end
                            idx <= 4'd7;
                        end
                        4'd7: begin
                            if (match_7) begin
                                temp_result_7 <= l1_7;
                                result_count <= temp_count + 1'b1;
                            end else begin
                                result_count <= temp_count;
                            end
                            state <= OUTPUT;
                            idx <= 4'd0;
                        end
                        default: begin
                            state <= OUTPUT;
                        end
                    endcase
                end
                
                OUTPUT: begin
                    // Transfer temp results to output ports
                    result_0 <= temp_result_0;
                    result_1 <= temp_result_1;
                    result_2 <= temp_result_2;
                    result_3 <= temp_result_3;
                    result_4 <= temp_result_4;
                    result_5 <= temp_result_5;
                    result_6 <= temp_result_6;
                    result_7 <= temp_result_7;
                    done <= 1'b1;
                    state <= FINISHED;
                end
                
                FINISHED: begin
                    done <= 1'b0;
                    if (!start) begin
                        state <= IDLE;
                    end
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule