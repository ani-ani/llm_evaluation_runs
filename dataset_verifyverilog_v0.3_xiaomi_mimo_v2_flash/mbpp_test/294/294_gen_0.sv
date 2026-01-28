module max_filtered (
    input clk,
    input rst_n,
    input start,
    input [7:0] arr [0:7],
    input [2:0] len,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE    = 2'd2;
    
    reg [1:0] state;
    reg [2:0] index;           // Current index in array (0-7)
    reg [7:0] current_max;     // Track maximum found
    reg found_valid;           // Flag: at least one non-sentinel found
    reg [3:0] cycle_count;     // Safety counter (max 10 cycles)
    localparam [3:0] MAX_CYCLES = 4'd10;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 8'd0;
            done <= 1'b0;
            index <= 3'd0;
            current_max <= 8'd0;
            found_valid <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    index <= 3'd0;
                    current_max <= 8'd0;
                    found_valid <= 1'b0;
                    cycle_count <= 4'd0;
                    
                    if (start) begin
                        // Start processing if len > 0
                        if (len > 3'd0) begin
                            state <= COMPARE;
                        end else begin
                            // Empty array - go to DONE immediately
                            state <= DONE;
                        end
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Check current element if it's a valid index
                    if (index < len) begin
                        // Filter out sentinel (0xFF)
                        if (arr[index] != 8'hFF) begin
                            // First valid integer found or new maximum
                            if (!found_valid || (arr[index] > current_max)) begin
                                current_max <= arr[index];
                            end
                            found_valid <= 1'b1;
                        end
                        index <= index + 3'd1;
                    end
                    
                    // Exit conditions
                    if (index >= (len - 3'd1)) begin
                        // Reached end of array
                        state <= DONE;
                    end else if (cycle_count >= MAX_CYCLES) begin
                        // Safety timeout
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= found_valid ? current_max : 8'd0;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule