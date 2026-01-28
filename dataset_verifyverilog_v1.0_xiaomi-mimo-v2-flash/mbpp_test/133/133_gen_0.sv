module sum_negatives(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] arr [0:15],
    input wire [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;
    
    reg [1:0] state;
    reg [3:0] index;
    reg signed [15:0] accumulator;
    reg [3:0] cycle_counter;
    localparam [3:0] MAX_CYCLES = 4'd16;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            index <= 4'd0;
            accumulator <= 16'sd0;
            cycle_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 4'd0;
                    accumulator <= 16'sd0;
                    cycle_counter <= 4'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Check if current element is negative (MSB = 1)
                    if (arr[index][7]) begin
                        // Sign-extend 8-bit to 16-bit and add
                        accumulator <= accumulator + { {8{arr[index][7]}}, arr[index] };
                    end
                    
                    // Increment index
                    index <= index + 4'd1;
                    
                    // Check completion conditions
                    if (index == (len - 4'd1) || cycle_counter >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= accumulator;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule