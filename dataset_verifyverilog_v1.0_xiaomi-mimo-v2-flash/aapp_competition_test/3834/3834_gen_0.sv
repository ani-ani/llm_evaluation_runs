module rectangle_pattern_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire row_valid,
    input wire [15:0] row_data,
    input wire [3:0] row_len,
    input wire [3:0] k_max,
    input wire done_config,
    output reg [3:0] result,
    output reg valid,
    output reg [1:0] status
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOADING = 2'd1;
    localparam [1:0] ENUMERATING = 2'd2;
    localparam [1:0] DONE = 2'd3;
    
    // Registers
    reg [1:0] state;
    reg [3:0] row_count;
    reg [15:0] rows [0:15]; // 16 rows of 16-bit data
    reg [3:0] row_lengths [0:15]; // 16 row lengths
    reg [3:0] stored_row_len;
    
    // Pattern enumeration registers
    reg [15:0] pattern;
    reg [15:0] pattern_next;
    reg [19:0] total_cost; // Max cost: 16 rows * 16 changes = 256
    reg [3:0] min_cost;
    reg [3:0] min_cost_next;
    
    // Row processing registers
    reg [3:0] row_index;
    reg [3:0] row_index_next;
    reg [15:0] xor_result;
    reg [3:0] popcount_xor;
    reg [3:0] popcount_xor_neg;
    reg [3:0] row_changes;
    
    // Popcount LUT (combinational)
    function [3:0] popcount16;
        input [15:0] x;
        begin
            popcount16 = x[0] + x[1] + x[2] + x[3] + x[4] + x[5] + x[6] + x[7] +
                        x[8] + x[9] + x[10] + x[11] + x[12] + x[13] + x[14] + x[15];
        end
    endfunction

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            row_count <= 4'd0;
            pattern <= 16'd0;
            min_cost <= 4'd15;
            row_index <= 4'd0;
            total_cost <= 20'd0;
            valid <= 1'b0;
            status <= 2'd0;
            result <= 4'd0;
            stored_row_len <= 4'd0;
            // Initialize rows array
            rows[0] <= 16'd0; rows[1] <= 16'd0; rows[2] <= 16'd0; rows[3] <= 16'd0;
            rows[4] <= 16'd0; rows[5] <= 16'd0; rows[6] <= 16'd0; rows[7] <= 16'd0;
            rows[8] <= 16'd0; rows[9] <= 16'd0; rows[10] <= 16'd0; rows[11] <= 16'd0;
            rows[12] <= 16'd0; rows[13] <= 16'd0; rows[14] <= 16'd0; rows[15] <= 16'd0;
            row_lengths[0] <= 4'd0; row_lengths[1] <= 4'd0; row_lengths[2] <= 4'd0; row_lengths[3] <= 4'd0;
            row_lengths[4] <= 4'd0; row_lengths[5] <= 4'd0; row_lengths[6] <= 4'd0; row_lengths[7] <= 4'd0;
            row_lengths[8] <= 4'd0; row_lengths[9] <= 4'd0; row_lengths[10] <= 4'd0; row_lengths[11] <= 4'd0;
            row_lengths[12] <= 4'd0; row_lengths[13] <= 4'd0; row_lengths[14] <= 4'd0; row_lengths[15] <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    valid <= 1'b0;
                    status <= 2'd0;
                    row_count <= 4'd0;
                    min_cost <= 4'd15;
                    if (start) begin
                        state <= LOADING;
                    end
                end
                
                LOADING: begin
                    if (row_valid && row_count < 4'd16) begin
                        rows[row_count] <= row_data;
                        row_lengths[row_count] <= row_len;
                        row_count <= row_count + 4'd1;
                    end
                    if (done_config) begin
                        state <= ENUMERATING;
                        pattern <= 16'd0;
                        row_index <= 4'd0;
                        total_cost <= 20'd0;
                        if (row_count > 4'd0) begin
                            stored_row_len <= row_lengths[row_count - 4'd1];
                        end
                    end
                end
                
                ENUMERATING: begin
                    if (row_index < row_count) begin
                        // Processing current row for current pattern
                        xor_result <= rows[row_index] ^ pattern;
                        // Store current row length for this row
                        stored_row_len <= row_lengths[row_index];
                        row_index <= row_index + 4'd1;
                    end else begin
                        // All rows processed for this pattern
                        if (total_cost[19:4] == 20'd0 && total_cost[3:0] <= k_max) begin
                            // Update minimum if this pattern is better
                            if (total_cost[3:0] < min_cost) begin
                                min_cost <= total_cost[3:0];
                            end
                        end
                        // Next pattern or done
                        if (pattern == 16'hFFFF) begin
                            state <= DONE;
                        end else begin
                            pattern <= pattern + 16'd1;
                            row_index <= 4'd0;
                            total_cost <= 20'd0;
                        end
                    end
                end
                
                DONE: begin
                    if (min_cost <= k_max) begin
                        result <= min_cost;
                        status <= 2'd1; // done
                        valid <= 1'b1;
                    end else begin
                        result <= 4'd15; // -1 representation
                        status <= 2'd2; // invalid/impossible
                        valid <= 1'b1;
                    end
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
            
            // Pipelined popcount calculation (3 cycles)
            // Cycle 1: compute popcount and neg popcount
            popcount_xor <= popcount16(xor_result);
            // Cycle 2: compute changes
            row_changes <= (popcount_xor < (stored_row_len - popcount_xor)) ? 
                           popcount_xor : (stored_row_len - popcount_xor);
            // Cycle 3: accumulate to total_cost
            if (state == ENUMERATING && row_index > 4'd0 && row_index <= row_count) begin
                total_cost <= total_cost + {16'd0, row_changes};
            end
        end
    end

endmodule