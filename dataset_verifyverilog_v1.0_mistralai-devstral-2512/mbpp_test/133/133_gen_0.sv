module sum_negative_numbers(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal signals
    reg [1:0] state, next_state;
    reg [3:0] index;
    reg signed [15:0] accumulator;
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            accumulator <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    accumulator <= 16'd0;
                    if (start) begin
                        next_state <= COMPUTE;
                    end else begin
                        next_state <= IDLE;
                    end
                end
                
                COMPUTE: begin
                    // Check if current element is negative
                    if (arr[index][7]) begin
                        accumulator <= accumulator + {{8{arr[index][7]}}, arr[index]};
                    end
                    
                    // Increment index
                    index <= index + 4'd1;
                    
                    // Check if done
                    if (index == len) begin
                        next_state <= FINISH;
                    end else begin
                        next_state <= COMPUTE;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;
                    next_state <= IDLE;
                end
                
                default: next_state <= IDLE;
            endcase
        end
    end
endmodule