module count_X(
    input clk,
    input rst_n,
    input start,
    input [7:0] x,
    input [7:0] arr [0:15],
    input [4:0] len,
    output reg [7:0] result,
    output reg done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [4:0] index;
    reg [7:0] count;
    reg [7:0] target_element;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 5'd0;
            count <= 8'd0;
            target_element <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 5'd0;
                    count <= 8'd0;
                    if (start) begin
                        target_element <= x;
                        state <= COUNTING;
                    end
                end
                
                COUNTING: begin
                    // Compare current element with target
                    if (arr[index] == target_element) begin
                        count <= count + 8'd1;
                    end
                    
                    // Increment index
                    index <= index + 5'd1;
                    
                    // Check if done counting
                    if (index == len - 5'd1) begin
                        result <= count;
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule