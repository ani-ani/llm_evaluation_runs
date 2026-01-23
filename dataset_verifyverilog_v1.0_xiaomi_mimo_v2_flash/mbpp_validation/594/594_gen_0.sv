module find_diff_first_even_odd (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [2:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg even_found;
    reg odd_found;
    reg signed [15:0] temp_result;
    
    // Input selection logic
    wire [7:0] current_val;
    assign current_val = (index == 3'd0) ? arr_0 :
                        (index == 3'd1) ? arr_1 :
                        (index == 3'd2) ? arr_2 :
                        (index == 3'd3) ? arr_3 :
                        (index == 3'd4) ? arr_4 :
                        (index == 3'd5) ? arr_5 :
                        (index == 3'd6) ? arr_6 :
                        arr_7;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            index <= 3'd0;
            first_even <= 8'd0;
            first_odd <= 8'd0;
            even_found <= 1'b0;
            odd_found <= 1'b0;
            temp_result <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    even_found <= 1'b0;
                    odd_found <= 1'b0;
                    first_even <= 8'd0;
                    first_odd <= 8'd0;
                    temp_result <= 16'd0;
                    
                    if (start && (len > 3'd0)) begin
                        state <= PROCESS;
                    end
                end
                
                PROCESS: begin
                    if (index < len) begin
                        // Process current element
                        if (!even_found && (current_val[0] == 1'b0)) begin
                            first_even <= current_val;
                            even_found <= 1'b1;
                        end
                        if (!odd_found && (current_val[0] == 1'b1)) begin
                            first_odd <= current_val;
                            odd_found <= 1'b1;
                        end
                        index <= index + 1'b1;
                    end else begin
                        // All elements processed
                        if (even_found && odd_found) begin
                            // Calculate difference (even - odd)
                            temp_result <= {8'd0, first_even} - {8'd0, first_odd};
                        end else if (even_found && !odd_found) begin
                            // No odd found, use -1
                            temp_result <= {8'd0, first_even} - 16'd1;
                        end else if (!even_found && odd_found) begin
                            // No even found, use -1
                            temp_result <= 16'd1 - {8'd0, first_odd};
                        end else begin
                            // Neither found (shouldn't happen with len>0)
                            temp_result <= 16'd0;
                        end
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= temp_result;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule