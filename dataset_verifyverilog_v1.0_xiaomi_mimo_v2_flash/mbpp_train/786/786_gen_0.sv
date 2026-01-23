module find_insertion_point (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [2:0] arr_len,
    input wire [7:0] target,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] left;
    reg [3:0] right;
    reg [3:0] mid;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd15;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            left <= 4'd0;
            right <= 4'd0;
            mid <= 4'd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        // Initialize binary search bounds
                        left <= 4'd0;
                        right <= {1'b0, arr_len}; // Convert 3-bit to 4-bit
                        state <= SEARCH;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Binary search: while (left < right)
                    if (left < right) begin
                        // mid = (left + right) >> 1
                        mid <= (left + right) >> 1;
                        
                        // Check arr[mid] <= target
                        // Note: arr[mid] when mid is 4-bit, but arr is 0:7
                        // We need to handle mid that might be 8 (right bound)
                        // Since we search arr[0:arr_len-1], mid will be 0-7
                        // If mid >= arr_len, it's out of bounds
                        
                        if (mid < {1'b0, arr_len} && arr[mid] <= target) begin
                            left <= mid + 4'd1;
                        end else begin
                            right <= mid;
                        end
                        
                        state <= SEARCH;
                    end else begin
                        // Search complete
                        result <= left;
                        state <= FINISH;
                    end
                    
                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= left;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule