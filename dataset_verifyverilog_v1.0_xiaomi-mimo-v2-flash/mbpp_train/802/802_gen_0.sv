module rotation_counter (
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
    input wire [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [3:0] rot_count;
    reg found;
    reg [7:0] current_val;
    reg [7:0] prev_val;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd10;
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            idx <= 4'd0;
            rot_count <= 4'd0;
            found <= 1'b0;
            current_val <= 8'd0;
            prev_val <= 8'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear done and prepare for new computation
                    done <= 1'b0;
                    result <= 4'd0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        // Initialize for computation
                        state <= CHECK;
                        idx <= 4'd1;  // Start comparing from index 1
                        rot_count <= 4'd0;
                        found <= 1'b0;
                        prev_val <= arr_0;
                    end
                end
                
                CHECK: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Get current value based on index
                    case (idx)
                        4'd1: current_val <= arr_1;
                        4'd2: current_val <= arr_2;
                        4'd3: current_val <= arr_3;
                        4'd4: current_val <= arr_4;
                        4'd5: current_val <= arr_5;
                        4'd6: current_val <= arr_6;
                        4'd7: current_val <= arr_7;
                        default: current_val <= 8'd0;
                    endcase
                    
                    // Check for rotation point
                    if (!found && (current_val < prev_val)) begin
                        found <= 1'b1;
                        rot_count <= idx;
                    end
                    
                    // Update prev_val for next iteration
                    // (will be used in next cycle)
                    if (idx < len) begin
                        prev_val <= current_val;
                    end
                    
                    // Move to next index or finish
                    if (idx < len - 4'd1) begin
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
                        // If no rotation found, result is 0 (already sorted)
                        if (!found) begin
                            rot_count <= 4'd0;
                        end
                    end
                    
                    // Safety: timeout if computation takes too long
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                        if (!found) begin
                            rot_count <= 4'd0;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= rot_count;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
endmodule