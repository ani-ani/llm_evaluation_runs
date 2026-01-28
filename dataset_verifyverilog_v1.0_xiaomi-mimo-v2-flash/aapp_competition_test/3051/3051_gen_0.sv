module FogCoverageCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire fog_valid,
    input wire [7:0] fog_day,
    input wire [3:0] fog_x1,
    input wire [3:0] fog_x2,
    input wire [3:0] fog_y1,
    input wire [3:0] fog_y2,
    output reg [7:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CHECK = 2'd1;
    localparam [2:0] UPDATE = 3'd2;
    localparam [1:0] FINISH = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [7:0] result_reg;
    reg [255:0] net_grid;
    
    // Coordinates registers
    reg [3:0] x1_reg;
    reg [3:0] x2_reg;
    reg [3:0] y1_reg;
    reg [3:0] y2_reg;
    
    // Iteration counters
    reg [3:0] x_idx;
    reg [3:0] y_idx;
    
    // Flags
    reg missed_flag;
    reg [1:0] fog_received;
    
    // Cycle counter for safety
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd5000;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'd0;
            result_reg <= 8'd0;
            net_grid <= 256'd0;
            x1_reg <= 4'd0;
            x2_reg <= 4'd0;
            y1_reg <= 4'd0;
            y2_reg <= 4'd0;
            x_idx <= 4'd0;
            y_idx <= 4'd0;
            missed_flag <= 1'b0;
            fog_received <= 2'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    result <= result_reg;
                    
                    if (start) begin
                        // Reset simulation state
                        result_reg <= 8'd0;
                        net_grid <= 256'd0;
                        fog_received <= 2'd0;
                    end else if (fog_valid && (fog_received == 2'd0)) begin
                        // Capture fog data
                        x1_reg <= fog_x1;
                        x2_reg <= fog_x2;
                        y1_reg <= fog_y1;
                        y2_reg <= fog_y2;
                        fog_received <= 2'd1;
                        state <= CHECK;
                    end
                end
                
                CHECK: begin
                    // Check if rectangle is fully covered
                    if (x_idx <= x2_reg && y_idx <= y2_reg) begin
                        // Calculate bit index: y_idx * 16 + x_idx
                        if (net_grid[(y_idx * 16) + x_idx] == 1'b0) begin
                            missed_flag <= 1'b1;
                        end
                        
                        // Increment x
                        if (x_idx < x2_reg) begin
                            x_idx <= x_idx + 4'd1;
                        end else begin
                            // Wrap x and increment y
                            x_idx <= x1_reg;
                            y_idx <= y_idx + 4'd1;
                        end
                    end else begin
                        // Finished checking
                        x_idx <= x1_reg;
                        y_idx <= y1_reg;
                        
                        if (missed_flag == 1'b1) begin
                            result_reg <= result_reg + 8'd1;
                            missed_flag <= 1'b0;
                            state <= UPDATE;
                        end else begin
                            // Fully covered, move to next fog
                            fog_received <= 2'd0;
                            state <= IDLE;
                        end
                    end
                end
                
                UPDATE: begin
                    // Update net grid by setting rectangle to 1
                    if (x_idx <= x2_reg && y_idx <= y2_reg) begin
                        net_grid[(y_idx * 16) + x_idx] <= 1'b1;
                        
                        if (x_idx < x2_reg) begin
                            x_idx <= x_idx + 4'd1;
                        end else begin
                            x_idx <= x1_reg;
                            y_idx <= y_idx + 4'd1;
                        end
                    end else begin
                        // Update complete
                        fog_received <= 2'd0;
                        state <= IDLE;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    result <= result_reg;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Handle termination (when stream ends)
            if (fog_received == 2'd0 && state != IDLE && state != FINISH) begin
                // Stream ended naturally
                cycle_count <= cycle_count + 16'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
            
            // Safety timeout for single fog operation
            if (state != IDLE) begin
                cycle_count <= cycle_count + 16'd1;
                if (cycle_count >= MAX_CYCLES) begin
                    state <= FINISH;
                end
            end
        end
    end

    // Always block for termination logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Handled above
        end else begin
            // External termination: when fog_valid is 0 and fog_received is 0
            // and we're in IDLE, and the testbench signals completion
            // This is simulated by the testbench controlling the stream
        end
    end

endmodule