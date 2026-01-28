module find_product_even_odd(
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
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SCAN = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] FINISH = 3'd3;
    
    reg [2:0] state, next_state;
    reg [3:0] idx;
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg found_even;
    reg found_odd;
    reg [7:0] current_val;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        case (state)
            IDLE: next_state = (start && (len > 4'd0)) ? SCAN : IDLE;
            SCAN: next_state = ((idx < len) && (!found_even || !found_odd)) ? SCAN : COMPUTE;
            COMPUTE: next_state = FINISH;
            FINISH: next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            idx <= 4'd0;
            first_even <= 8'd0;
            first_odd <= 8'd0;
            found_even <= 1'b0;
            found_odd <= 1'b0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            done <= 1'b0;
            case (state)
                IDLE: begin
                    idx <= 4'd0;
                    first_even <= 8'd0;
                    first_odd <= 8'd0;
                    found_even <= 1'b0;
                    found_odd <= 1'b0;
                end
                
                SCAN: begin
                    if (idx < len) begin
                        case (idx)
                            4'd0: current_val = arr_0;
                            4'd1: current_val = arr_1;
                            4'd2: current_val = arr_2;
                            4'd3: current_val = arr_3;
                            4'd4: current_val = arr_4;
                            4'd5: current_val = arr_5;
                            4'd6: current_val = arr_6;
                            4'd7: current_val = arr_7;
                            default: current_val = 8'd0;
                        endcase
                        
                        if (!found_even && !current_val[0]) begin
                            first_even <= current_val;
                            found_even <= 1'b1;
                        end
                        
                        if (!found_odd && current_val[0]) begin
                            first_odd <= current_val;
                            found_odd <= 1'b1;
                        end
                        
                        idx <= idx + 4'd1;
                    end
                end
                
                COMPUTE: begin
                    result <= $signed(found_even ? first_even : 8'hFF) * 
                              $signed(found_odd ? first_odd : 8'hFF);
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule