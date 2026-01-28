module TaxTracker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [8:0] data_in,
    input wire load_cmd,
    input wire data_valid,
    output reg [15:0] result,
    output reg [7:0] day_out,
    output reg output_valid,
    output reg done,
    output reg [3:0] output_index
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] INPUT = 3'd1;
    localparam [2:0] SORT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] FINISH = 3'd4;

    // Internal registers
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Record buffer: stores pending shares and day
    reg [8:0] pending_shares;
    reg pending_valid;
    
    // Storage: Max 10 records per company (scaled from 50)
    reg [7:0] days [0:9];      // Day index for each record
    reg [15:0] shares [0:9];   // Accumulated shares per day
    reg valid [0:9];           // Valid entry flag
    reg [3:0] record_count;    // Number of records stored (0-10)
    
    // Sorting indices
    reg [3:0] i_idx;
    reg [3:0] j_idx;
    reg [3:0] sort_count;
    
    // Output index
    reg [3:0] out_idx;
    reg [3:0] out_count;
    
    // Cycle counter for timeout protection
    reg [8:0] cycle_count;
    localparam [8:0] MAX_CYCLES = 9'd256;
    
    // Temp variables for swapping
    reg [7:0] temp_day;
    reg [15:0] temp_shares;
    reg temp_valid;
    
    integer k;

    // State transition logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = INPUT;
            end
            INPUT: begin
                // Transition when input is full or start drops low
                if (record_count >= 10'd10 && !data_valid)
                    next_state = SORT;
                else if (!start && !data_valid && record_count > 0)
                    next_state = SORT;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = SORT;
            end
            SORT: begin
                // Bubble sort: check if complete
                if (sort_count >= 10'd9)
                    next_state = OUTPUT;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = OUTPUT;
            end
            OUTPUT: begin
                // Done when we've processed all records
                if (out_count >= record_count)
                    next_state = FINISH;
                else if (cycle_count >= MAX_CYCLES)
                    next_state = FINISH;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            pending_shares <= 9'd0;
            pending_valid <= 1'b0;
            record_count <= 4'd0;
            i_idx <= 4'd0;
            j_idx <= 4'd0;
            sort_count <= 4'd0;
            out_idx <= 4'd0;
            out_count <= 4'd0;
            cycle_count <= 9'd0;
            result <= 16'd0;
            day_out <= 8'd0;
            output_valid <= 1'b0;
            done <= 1'b0;
            output_index <= 4'd0;
            
            // Initialize arrays
            for (k = 0; k < 10; k = k + 1) begin
                days[k] <= 8'd0;
                shares[k] <= 16'd0;
                valid[k] <= 1'b0;
            end
            
        end else begin
            // Default outputs
            output_valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    // Wait for start
                    if (start) begin
                        // Clear all storage
                        record_count <= 4'd0;
                        pending_shares <= 9'd0;
                        pending_valid <= 1'b0;
                        cycle_count <= 9'd0;
                        for (k = 0; k < 10; k = k + 1) begin
                            days[k] <= 8'd0;
                            shares[k] <= 16'd0;
                            valid[k] <= 1'b0;
                        end
                    end
                end
                
                INPUT: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    if (data_valid && !load_cmd && record_count < 10'd10) begin
                        // Load shares (first in pair)
                        pending_shares <= data_in;
                        pending_valid <= 1'b1;
                    end
                    else if (data_valid && load_cmd && pending_valid && record_count < 10'd10) begin
                        // Load day (second in pair) - store complete record
                        days[record_count] <= data_in[7:0];
                        shares[record_count] <= {7'd0, pending_shares};
                        valid[record_count] <= 1'b1;
                        record_count <= record_count + 4'd1;
                        pending_valid <= 1'b0;
                        pending_shares <= 9'd0;
                    end
                end
                
                SORT: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    // Bubble sort implementation
                    if (sort_count < record_count - 4'd1) begin
                        if (i_idx < record_count - sort_count - 4'd1) begin
                            // Compare adjacent elements
                            if (days[i_idx] > days[i_idx + 4'd1] && valid[i_idx] && valid[i_idx + 4'd1]) begin
                                // Swap days
                                temp_day <= days[i_idx];
                                days[i_idx] <= days[i_idx + 4'd1];
                                days[i_idx + 4'd1] <= temp_day;
                                
                                // Swap shares
                                temp_shares <= shares[i_idx];
                                shares[i_idx] <= shares[i_idx + 4'd1];
                                shares[i_idx + 4'd1] <= temp_shares;
                                
                                // Swap valid flags
                                temp_valid <= valid[i_idx];
                                valid[i_idx] <= valid[i_idx + 4'd1];
                                valid[i_idx + 4'd1] <= temp_valid;
                            end
                            i_idx <= i_idx + 4'd1;
                        end else begin
                            i_idx <= 4'd0;
                            sort_count <= sort_count + 4'd1;
                        end
                    end
                end
                
                OUTPUT: begin
                    cycle_count <= cycle_count + 9'd1;
                    
                    if (out_idx < record_count) begin
                        if (valid[out_idx]) begin
                            result <= shares[out_idx];
                            day_out <= days[out_idx];
                            output_index <= out_idx;
                            output_valid <= 1'b1;
                            out_idx <= out_idx + 4'd1;
                            out_count <= out_count + 4'd1;
                        end else begin
                            // Skip invalid entries
                            out_idx <= out_idx + 4'd1;
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Reset for next operation
                    out_idx <= 4'd0;
                    out_count <= 4'd0;
                    sort_count <= 4'd0;
                    i_idx <= 4'd0;
                    cycle_count <= 9'd0;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
    
    // Continuous state update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

endmodule