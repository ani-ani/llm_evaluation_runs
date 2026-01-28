module ArrayThresholdCheck(
    input clk,
    input rst_n,
    input start,
    input [7:0] threshold,
    input [7:0] arr [0:7],
    output reg result,
    output reg done
);
    
    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CHECK   = 3'd1;
    localparam [2:0] FINISH  = 3'd2;
    
    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] index;
    reg [7:0] current_element;
    reg all_below;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 3'd0;
            all_below <= 1'b1;
            result <= 1'b0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 3'd0;
                        all_below <= 1'b1;
                        next_state <= CHECK;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                CHECK: begin
                    current_element <= arr[index];
                    if (current_element >= threshold) begin
                        all_below <= 1'b0;
                    end
                    
                    if (index == 3'd7) begin
                        next_state <= FINISH;
                    end else begin
                        index <= index + 3'd1;
                        next_state <= CHECK;
                    end
                end
                
                FINISH: begin
                    result <= all_below;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule