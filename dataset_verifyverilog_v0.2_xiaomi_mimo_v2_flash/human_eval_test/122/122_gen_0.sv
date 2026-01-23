module sum_two_digit_k(
    input clk,
    input rst_n,
    input [2:0] k,
    input signed [7:0] arr [0:7],
    output reg signed [10:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [2:0] index;
    wire signed [7:0] current_val;
    wire [7:0] abs_val;
    
    // Get current value from array based on index
    assign current_val = arr[index];
    
    // Calculate absolute value using ternary operator
    // Note: -128 is a special case but for <= 99 check it works fine
    assign abs_val = (current_val[7]) ? (~current_val + 1'b1) : current_val;

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 11'sd0;
            done <= 1'b0;
            index <= 3'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Start processing immediately after reset is released
                    result <= 11'sd0;
                    done <= 1'b0;
                    index <= 3'b0;
                    state <= PROCESSING;
                end
                
                PROCESSING: begin
                    if (index < k) begin
                        // Check if absolute value <= 99
                        if (abs_val <= 8'd99) begin
                            result <= result + current_val;
                        end
                        index <= index + 1'b1;
                        
                        // If we processed the last element (k-1), next cycle is DONE
                        if (index == k - 1'b1) begin
                            state <= DONE;
                        end
                    end else begin
                        // Safety fallback (shouldn't normally happen)
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    // Hold state and result
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule