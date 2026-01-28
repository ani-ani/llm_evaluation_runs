module DifferenceFirstEvenOdd (
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
    output reg signed [15:0] result,
    output reg done
);

    // State definitions for single-cycle operation
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg signed [15:0] next_result;
    reg next_done;
    
    // Combinatorial scan logic
    reg [7:0] first_even;
    reg [7:0] first_odd;
    reg found_even;
    reg found_odd;
    integer i;
    reg [7:0] element;
    
    // Combinatorial scan process
    always @(*) begin
        first_even = 8'd0;
        first_odd = 8'd0;
        found_even = 1'b0;
        found_odd = 1'b0;
        
        // Sequential scan from index 0 to 7
        for (i = 0; i < 8; i = i + 1) begin
            case (i)
                0: element = arr_0;
                1: element = arr_1;
                2: element = arr_2;
                3: element = arr_3;
                4: element = arr_4;
                5: element = arr_5;
                6: element = arr_6;
                7: element = arr_7;
                default: element = 8'd0;
            endcase
            
            if (!found_even && element[0] == 1'b0) begin
                first_even = element;
                found_even = 1'b1;
            end
            
            if (!found_odd && element[0] == 1'b1) begin
                first_odd = element;
                found_odd = 1'b1;
            end
        end
    end
    
    // State machine for done signal
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    // Compute signed difference
                    next_result = ({8'd0, first_even} - {8'd0, first_odd});
                    
                    // Clamp to 16-bit signed range (-32768 to 32767)
                    if (next_result > 16'sd32767) begin
                        result <= 16'sd32767;
                    end else if (next_result < -16'sd32768) begin
                        result <= -16'sd32768;
                    end else begin
                        result <= next_result;
                    end
                    
                    state <= FINISH;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 16'sd0;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule