module HouseHeightCalculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [31:0] k_fixed,
    input wire signed [31:0] h_init [0:7],
    input wire [3:0] n,
    output reg signed [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] LOAD    = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    
    // Height registers
    reg signed [31:0] h [0:7];
    
    // Current index for computation
    reg [2:0] current_index;
    
    // Temporary variables for computation
    reg signed [31:0] neighbor_sum;
    reg signed [31:0] new_val;
    
    // Max height calculation
    reg signed [31:0] max_height;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            cycle_count <= 8'd0;
            current_index <= 3'd0;
            result <= 32'd0;
            done <= 1'b0;
            
            // Initialize height registers
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                h[i] <= 32'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                    end
                end
                
                LOAD: begin
                    // Load initial heights
                    integer i;
                    for (i = 0; i < 8; i = i + 1) begin
                        if (i < n) begin
                            h[i] <= h_init[i];
                        end else begin
                            h[i] <= 32'd0;
                        end
                    end
                    cycle_count <= 8'd0;
                    current_index <= 3'd0;
                    state <= COMPUTE;
                end
                
                COMPUTE: begin
                    // Compute neighbor sum
                    if (current_index == 0) begin
                        neighbor_sum = h[1];
                    end else if (current_index == n - 1) begin
                        neighbor_sum = h[current_index - 1];
                    end else begin
                        neighbor_sum = h[current_index - 1] + h[current_index + 1];
                    end
                    
                    // Calculate new value
                    new_val = (neighbor_sum >> 1) + k_fixed;
                    
                    // Update height
                    if (new_val > h[current_index]) begin
                        h[current_index] <= new_val;
                    end
                    
                    // Move to next index
                    if (current_index == n - 1) begin
                        current_index <= 3'd0;
                        cycle_count <= cycle_count + 8'd1;
                        
                        // Check if done
                        if (cycle_count >= MAX_CYCLES) begin
                            state <= FINISH;
                        end
                    end else begin
                        current_index <= current_index + 3'd1;
                    end
                end
                
                FINISH: begin
                    // Find max height
                    integer i;
                    max_height = h[0];
                    for (i = 1; i < 8; i = i + 1) begin
                        if (h[i] > max_height) begin
                            max_height = h[i];
                        end
                    end
                    result <= max_height;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule