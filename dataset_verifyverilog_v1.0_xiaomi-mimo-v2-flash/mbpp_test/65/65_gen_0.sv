module SumNestedList (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] data [0:15][0:15],
    input wire [3:0] valid_len [0:15],
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE        = 3'd0;
    localparam [2:0] CHECK_LEVEL = 3'd1;
    localparam [2:0] SUM_LEVEL   = 3'd2;
    localparam [2:0] NEXT_LEVEL  = 3'd3;
    localparam [2:0] FINISH      = 3'd4;

    // Registers
    reg [2:0] state;
    reg [3:0] level_idx;      // Current level (0-15)
    reg [3:0] elem_idx;       // Current element within level (0-15)
    reg [7:0] cycle_count;    // Cycle counter to prevent infinite loops
    reg signed [15:0] acc;    // Accumulator

    // Constants
    localparam [7:0] MAX_CYCLES = 8'd200;  // Safe upper bound

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            level_idx <= 4'd0;
            elem_idx <= 4'd0;
            cycle_count <= 8'd0;
            acc <= 16'sd0;
            result <= 16'sd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    // Clear done signal when idle
                    done <= 1'b0;
                    // Reset counters
                    level_idx <= 4'd0;
                    elem_idx <= 4'd0;
                    cycle_count <= 8'd0;
                    acc <= 16'sd0;
                    
                    if (start) begin
                        state <= CHECK_LEVEL;
                    end
                end

                CHECK_LEVEL: begin
                    // Check if current level has any valid elements
                    if (level_idx < 16) begin
                        if (valid_len[level_idx] > 4'd0) begin
                            elem_idx <= 4'd0;  // Reset element index
                            state <= SUM_LEVEL;
                        end else begin
                            state <= NEXT_LEVEL;  // Skip empty level
                        end
                    end else begin
                        // All levels processed
                        state <= FINISH;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                SUM_LEVEL: begin
                    // Process each element in current level
                    if (elem_idx < valid_len[level_idx]) begin
                        // Only add non-zero values
                        if (data[level_idx][elem_idx] != 8'sd0) begin
                            acc <= acc + {8'd0, data[level_idx][elem_idx]};
                        end
                        elem_idx <= elem_idx + 4'd1;
                    end else begin
                        // Level complete
                        state <= NEXT_LEVEL;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                NEXT_LEVEL: begin
                    // Move to next level
                    level_idx <= level_idx + 4'd1;
                    state <= CHECK_LEVEL;
                    cycle_count <= cycle_count + 8'd1;
                end

                FINISH: begin
                    // Set output and done signal
                    result <= acc;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase

            // Safety: abort if too many cycles
            if (cycle_count >= MAX_CYCLES) begin
                state <= FINISH;
                result <= acc;
                done <= 1'b1;
            end
        end
    end

endmodule