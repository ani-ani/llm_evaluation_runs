module sum_squares(
    input clk,
    input rst_n,
    input start,
    input signed [15:0] arr [0:15],
    input [3:0] len,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] index;
    reg [31:0] temp_sum;
    reg [31:0] processed_val;
    reg done_reg;
    reg busy;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            index <= 4'd0;
            temp_sum <= 32'd0;
            processed_val <= 32'd0;
            result <= 16'd0;
            done <= 1'b0;
            done_reg <= 1'b0;
            busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    done_reg <= 1'b0;
                    busy <= 1'b0;
                    if (start) begin
                        state <= PROCESS;
                        busy <= 1'b1;
                        index <= 4'd0;
                        temp_sum <= 32'd0;
                    end
                end
                
                PROCESS: begin
                    // Process current element
                    if (index < len) begin
                        // Sign extend input to 32 bits
                        reg signed [31:0] current_val;
                        current_val = {{16{arr[index][15]}}, arr[index]};
                        
                        // Apply transformation based on index
                        if (index % 3 == 0) begin
                            // Square the element
                            processed_val = current_val * current_val;
                        end else if (index % 4 == 0) begin
                            // Cube the element
                            processed_val = current_val * current_val * current_val;
                        end else begin
                            // Keep element unchanged
                            processed_val = current_val;
                        end
                        
                        // Accumulate to temp_sum
                        temp_sum = temp_sum + processed_val;
                        
                        // Move to next index
                        index = index + 4'd1;
                    end else begin
                        // All elements processed
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    // Output final result (truncate to 16-bit signed)
                    result <= temp_sum[31:16];
                    done <= 1'b1;
                    done_reg <= 1'b1;
                    busy <= 1'b0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule