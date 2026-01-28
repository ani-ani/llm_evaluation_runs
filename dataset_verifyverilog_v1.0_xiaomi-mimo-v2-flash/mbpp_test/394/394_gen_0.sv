module DuplicateChecker (
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
    input wire [7:0] arr_8,
    input wire [7:0] arr_9,
    input wire [7:0] arr_10,
    input wire [7:0] arr_11,
    input wire [7:0] arr_12,
    input wire [7:0] arr_13,
    input wire [7:0] arr_14,
    input wire [7:0] arr_15,
    input wire [3:0] len,
    output reg result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] CHECKING = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] i;          // Outer loop index (element being checked)
    reg [3:0] j;          // Inner loop index (element to compare against)
    reg duplicate_found;
    reg [7:0] i_val;      // Store value at position i
    reg [7:0] j_val;      // Store value at position j
    reg [7:0] current_val;
    
    // Cycle counter to prevent infinite loops
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Helper function to get array element by index
    function [7:0] get_element;
        input [3:0] idx;
        case (idx)
            4'd0: get_element = arr_0;
            4'd1: get_element = arr_1;
            4'd2: get_element = arr_2;
            4'd3: get_element = arr_3;
            4'd4: get_element = arr_4;
            4'd5: get_element = arr_5;
            4'd6: get_element = arr_6;
            4'd7: get_element = arr_7;
            4'd8: get_element = arr_8;
            4'd9: get_element = arr_9;
            4'd10: get_element = arr_10;
            4'd11: get_element = arr_11;
            4'd12: get_element = arr_12;
            4'd13: get_element = arr_13;
            4'd14: get_element = arr_14;
            4'd15: get_element = arr_15;
            default: get_element = 8'd0;
        endcase
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            duplicate_found <= 1'b0;
            i_val <= 8'd0;
            j_val <= 8'd0;
            current_val <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    i <= 4'd0;
                    j <= 4'd1;
                    duplicate_found <= 1'b0;
                    cycle_count <= 8'd0;
                    
                    if (start && len > 4'd1) begin
                        // Get first element to compare
                        current_val <= get_element(4'd0);
                        state <= CHECKING;
                    end else if (start && len == 4'd1) begin
                        // Only one element - always unique
                        result <= 1'b1;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end
                
                CHECKING: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare current_val with element at position j
                    if (current_val == get_element(j)) begin
                        duplicate_found <= 1'b1;
                        result <= 1'b0;
                        state <= DONE;
                    end else begin
                        // Move to next comparison
                        j <= j + 4'd1;
                        
                        // Check if finished inner loop for current i
                        if (j + 4'd1 >= len) begin
                            // Finished comparing element i, move to next element
                            i <= i + 4'd1;
                            
                            // Check if finished all elements
                            if (i + 4'd2 >= len) begin
                                // All elements checked, no duplicates found
                                result <= 1'b1;
                                state <= DONE;
                            end else begin
                                // Start checking next element
                                j <= i + 4'd2;
                                current_val <= get_element(i + 4'd1);
                            end
                        end
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule