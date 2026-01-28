module min_subarray_kadane (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] data_in,
    input wire data_valid,
    input wire data_end,
    output reg signed [15:0] result,
    output reg result_valid,
    output reg done
);

    // State machine declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE = 2'd2;
    
    reg [1:0] state;
    reg signed [15:0] current_sum;
    reg signed [15:0] min_sum;
    reg signed [16:0] extended_sum; // 17-bit for overflow detection
    reg [4:0] data_count; // Counter for up to 16 elements
    reg [5:0] cycle_count; // Prevent infinite loops (max 64 cycles)
    localparam [5:0] MAX_CYCLES = 6'd40; // 16 data + overhead

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            result <= 16'sd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            current_sum <= 16'sd0;
            min_sum <= 16'sd0;
            extended_sum <= 17'sd0;
            data_count <= 5'd0;
            cycle_count <= 6'd0;
        end else begin
            // Default outputs
            done <= 1'b0;
            result_valid <= 1'b0;
            
            case (state)
                IDLE: begin
                    data_count <= 5'd0;
                    cycle_count <= 6'd0;
                    if (start) begin
                        current_sum <= 16'sd0;
                        min_sum <= 16'h7FFF; // Maximum positive (0x7FFF)
                        state <= PROCESSING;
                    end
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 6'd1;
                    
                    if (data_valid) begin
                        data_count <= data_count + 5'd1;
                        
                        // Calculate extended sum for overflow detection
                        extended_sum <= {current_sum[15], current_sum} + {data_in[15], data_in};
                        
                        // Check for overflow/clamping in next cycle
                        // (We'll update current_sum in next cycle to avoid combinational paths)
                        // For now, we'll do the operations directly
                        
                        // Update current_sum: current_sum = current_sum + data_in
                        // Handle overflow by clamping
                        if (extended_sum > 17'sd32767) begin
                            current_sum <= 16'sd32767; // Clamp to max
                        end else if (extended_sum < -17'sd32768) begin
                            current_sum <= -16'sd32768; // Clamp to min
                        end else begin
                            current_sum <= extended_sum[15:0];
                        end
                        
                        // Check if current_sum > min_sum
                        if (extended_sum[15:0] > min_sum) begin
                            min_sum <= extended_sum[15:0];
                        end
                        
                        // If current_sum > 0, reset to 0 (restart subarray)
                        if (extended_sum[15:0] > 16'sd0) begin
                            current_sum <= 16'sd0;
                        end
                    end
                    
                    // Transition to DONE when data_end is received
                    if (data_end || cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    result <= min_sum;
                    result_valid <= 1'b1;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule