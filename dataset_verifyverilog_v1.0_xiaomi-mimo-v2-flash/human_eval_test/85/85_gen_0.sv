module SumEvenAtOddIndices (
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
    output reg [15:0] result,
    output reg done
);
    // State machine definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [2:0] counter;  // 0 to 7
    reg [15:0] sum;
    reg [7:0] current_element;
    
    // Cycle counter for safety (max 100 cycles)
    reg [6:0] cycle_count;
    localparam [6:0] MAX_CYCLES = 7'd100;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            counter <= 3'd0;
            sum <= 16'd0;
            current_element <= 8'd0;
            cycle_count <= 7'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    counter <= 3'd0;
                    sum <= 16'd0;
                    cycle_count <= 7'd0;
                    
                    if (start) begin
                        state <= CALCULATE;
                    end
                end
                
                CALCULATE: begin
                    cycle_count <= cycle_count + 7'd1;
                    
                    // Get element based on counter
                    case (counter)
                        3'd0: current_element <= arr_0;
                        3'd1: current_element <= arr_1;
                        3'd2: current_element <= arr_2;
                        3'd3: current_element <= arr_3;
                        3'd4: current_element <= arr_4;
                        3'd5: current_element <= arr_5;
                        3'd6: current_element <= arr_6;
                        3'd7: current_element <= arr_7;
                        default: current_element <= 8'd0;
                    endcase
                    
                    // Check conditions: index is odd (counter[0] == 1) and element is even (LSB == 0)
                    if (counter[0] == 1'b1 && current_element[0] == 1'b0) begin
                        sum <= sum + {8'd0, current_element};
                    end
                    
                    counter <= counter + 3'd1;
                    
                    // Exit when counter wraps to 0 or max cycles reached
                    if (counter == 3'd7 || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= sum;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule