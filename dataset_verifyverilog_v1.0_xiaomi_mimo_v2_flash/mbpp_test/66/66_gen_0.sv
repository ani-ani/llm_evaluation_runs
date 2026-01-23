module pos_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done
);
    // Parameters
    parameter MAX_SIZE = 4;
    
    // Internal state
    reg [1:0] state;
    reg [1:0] index;
    reg [3:0] count;
    reg signed [7:0] current_num;
    
    // State definitions
    localparam IDLE = 2'b00;
    localparam COMPUTE = 2'b01;
    localparam FINISH = 2'b10;
    
    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 4'd0;
            count <= 4'd0;
            index <= 2'd0;
            current_num <= 8'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        index <= 2'd0;
                        count <= 4'd0;
                    end
                end
                
                COMPUTE: begin
                    // Select current number based on index
                    case (index)
                        2'd0: current_num <= arr_0;
                        2'd1: current_num <= arr_1;
                        2'd2: current_num <= arr_2;
                        2'd3: current_num <= arr_3;
                        default: current_num <= 8'sd0;
                    endcase
                    
                    // Check if index is within valid range (0 to len-1)
                    // Count if current_num >= 0 (positive or zero)
                    if (index < len && current_num >= 8'sd0) begin
                        count <= count + 4'd1;
                    end
                    
                    // Move to next element or finish
                    // len is 4-bit, so len-1 can be 15, but index is only 2-bit (max 3)
                    // For safety, check if index is at max or len-1 reached
                    if (index < 2'd3 && index < len - 1) begin
                        index <= index + 2'd1;
                    end else begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule