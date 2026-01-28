module array_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:11],
    input [7:0] target,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg [15:0] count;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            count <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        index <= 4'd0;
                        count <= 16'd0;
                        next_state <= COUNTING;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COUNTING: begin
                    if (arr[index] == target) begin
                        count <= count + 16'd1;
                    end
                    
                    if (index == len - 4'd1) begin
                        next_state <= DONE_STATE;
                    end else begin
                        index <= index + 4'd1;
                        next_state <= COUNTING;
                    end
                end
                
                DONE_STATE: begin
                    result <= count;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule