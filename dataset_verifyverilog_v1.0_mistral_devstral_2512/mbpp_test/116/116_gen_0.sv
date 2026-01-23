module tuple_to_int (
    input clk,
    input rst_n,
    input start,
    input [3:0] len,              // Number of elements (max 8)
    input [3:0] arr_0,            // Digit 0 (0-9)
    input [3:0] arr_1,            // Digit 1 (0-9)
    input [3:0] arr_2,            // Digit 2 (0-9)
    input [3:0] arr_3,            // Digit 3 (0-9)
    input [3:0] arr_4,            // Digit 4 (0-9)
    input [3:0] arr_5,            // Digit 5 (0-9)
    input [3:0] arr_6,            // Digit 6 (0-9)
    input [3:0] arr_7,            // Digit 7 (0-9)
    output reg [31:0] result,     // Result fits in 32 bits
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    reg [1:0] state;
    reg [3:0] idx;           // Current index (0-7)
    reg [31:0] accumulator;  // Running sum
    reg [7:0] cycle_count;  // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            idx <= 4'd0;
            accumulator <= 32'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;  // Clear done when idle
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        idx <= 4'd0;
                        accumulator <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current digit
                    case (idx)
                        4'd0: accumulator <= accumulator * 10 + arr_0;
                        4'd1: accumulator <= accumulator * 10 + arr_1;
                        4'd2: accumulator <= accumulator * 10 + arr_2;
                        4'd3: accumulator <= accumulator * 10 + arr_3;
                        4'd4: accumulator <= accumulator * 10 + arr_4;
                        4'd5: accumulator <= accumulator * 10 + arr_5;
                        4'd6: accumulator <= accumulator * 10 + arr_6;
                        4'd7: accumulator <= accumulator * 10 + arr_7;
                    endcase
                    
                    // Move to next digit or finish
                    if (idx < len - 1 && idx < 7) begin
                        idx <= idx + 1;
                    end else begin
                        state <= FINISH;
                    end
                    
                    // Exit conditions (MUST have at least one!)
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= accumulator;
                    done <= 1'b1;  // Assert done
                    state <= IDLE;  // Return to idle
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule