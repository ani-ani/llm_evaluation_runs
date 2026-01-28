module find_smallest_even (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result_val,
    output reg [3:0] result_idx,
    output reg done,
    output reg valid
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SCAN    = 2'd1;
    localparam [1:0] UPDATE  = 2'd2;
    localparam [1:0] DONE    = 2'd3;
    
    reg [1:0] state;
    reg [3:0] i;  // Current index (0 to 15)
    reg [7:0] best_val;  // Best even value found
    reg [3:0] best_idx;  // Index of best value
    reg found_even;  // Flag to track if any even was found
    reg [3:0] cycle_counter;  // Prevent infinite loops
    localparam [3:0] MAX_CYCLES = 4'd20;  // 16 elements max + overhead
    
    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result_val <= 8'hFF;
            result_idx <= 4'hF;
            done <= 1'b0;
            valid <= 1'b0;
            i <= 4'd0;
            best_val <= 8'hFF;
            best_idx <= 4'hF;
            found_even <= 1'b0;
            cycle_counter <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid <= 1'b0;
                    cycle_counter <= 4'd0;
                    i <= 4'd0;
                    best_val <= 8'hFF;
                    best_idx <= 4'hF;
                    found_even <= 1'b0;
                    result_val <= 8'hFF;
                    result_idx <= 4'hF;
                    
                    if (start) begin
                        if (len == 4'd0) begin
                            // Handle empty array immediately
                            state <= DONE;
                            found_even <= 1'b0;
                        end else begin
                            state <= SCAN;
                        end
                    end
                end
                
                SCAN: begin
                    cycle_counter <= cycle_counter + 4'd1;
                    
                    // Check if current element is even
                    if (arr[i][0] == 1'b0) begin  // Even check
                        if (!found_even || (arr[i] < best_val)) begin
                            // First even or smaller even found
                            best_val <= arr[i];
                            best_idx <= i;
                            found_even <= 1'b1;
                        end
                        // If equal value, keep smaller index (already stored)
                    end
                    
                    i <= i + 4'd1;
                    
                    // Check for end conditions
                    if ((i == len - 4'd1) || (cycle_counter >= MAX_CYCLES)) begin
                        state <= UPDATE;
                    end
                end
                
                UPDATE: begin
                    if (found_even) begin
                        result_val <= best_val;
                        result_idx <= best_idx;
                        valid <= 1'b1;
                    end else begin
                        // No even found or invalid
                        result_val <= 8'hFF;
                        result_idx <= 4'hF;
                        valid <= 1'b0;
                    end
                    state <= DONE;
                end
                
                DONE: begin
                    done <= 1'b1;  // Pulse done
                    state <= IDLE;  // Return to idle
                end
                
                default: state <= IDLE;
            endcase
        end
    end
    
endmodule