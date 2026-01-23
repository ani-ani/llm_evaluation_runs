module prod_signs(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input valid,
    output reg [15:0] result,
    output reg done
);
    
    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;
    
    reg signed [9:0] sum_magnitudes;
    reg signed [0:0] product_signs;
    reg [3:0] index;
    reg [7:0] current_magnitude;
    reg current_sign;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            sum_magnitudes <= 10'd0;
            product_signs <= 1'd1;
            index <= 4'd0;
            current_magnitude <= 8'd0;
            current_sign <= 1'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Process array elements
                    if (index < 8) begin
                        // Calculate magnitude and sign for current element
                        if (arr[index][7]) begin
                            // Negative number
                            current_magnitude <= -arr[index];
                            current_sign <= 1'd1;
                        end else if (arr[index] == 0) begin
                            // Zero
                            current_magnitude <= 8'd0;
                            current_sign <= 1'd0;
                        end else begin
                            // Positive number
                            current_magnitude <= arr[index];
                            current_sign <= 1'd0;
                        end
                        
                        // Update sum of magnitudes
                        sum_magnitudes <= sum_magnitudes + current_magnitude;
                        
                        // Update product of signs
                        if (current_sign) begin
                            product_signs <= -product_signs;
                        end else if (arr[index] == 0) begin
                            product_signs <= 1'd0;
                        end
                        
                        index <= index + 4'd1;
                    end
                    
                    // Check if computation is complete
                    if ((index >= 8) || (cycle_count >= MAX_CYCLES)) begin
                        if (valid) begin
                            // Final result: product_signs * sum_magnitudes
                            result <= product_signs * sum_magnitudes;
                        end else begin
                            result <= 16'd0;
                        end
                        state <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule