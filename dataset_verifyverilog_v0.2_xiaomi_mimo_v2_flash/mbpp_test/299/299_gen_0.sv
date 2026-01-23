module max_aggregate (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] num_entries,
    input wire [63:0] name_in,
    input wire [7:0] marks_in,
    input wire valid_in,
    output reg [63:0] result_name,
    output reg [9:0] result_total,
    output reg done,
    output reg error
);

    // Register file: 8 entries of (name, total)
    reg [63:0] reg_names [0:7];
    reg [9:0] reg_totals [0:7];
    reg [7:0] valid_mask;

    // FSM states
    localparam IDLE = 3'b000;
    localparam ACCUMULATE = 3'b001;
    localparam FIND_MAX = 3'b010;
    localparam DONE = 3'b011;
    localparam SEARCH = 3'b100;

    reg [2:0] state, next_state;
    
    // Counters and indices
    reg [2:0] entry_cnt;      // Tracks how many inputs processed
    reg [2:0] idx;            // Search index
    reg [2:0] empty_idx;      // First empty slot found
    reg found_match;          // Match flag
    reg found_empty;          // Empty slot flag
    reg [2:0] max_idx;        // Index of max total
    reg [9:0] max_total;      // Current max total
    
    // Temporary variables
    reg [9:0] new_total;
    integer i;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    if (num_entries == 3'b000) begin
                        next_state = DONE;
                    end else begin
                        next_state = ACCUMULATE;
                    end
                end else begin
                    next_state = IDLE;
                end
            end
            
            ACCUMULATE: begin
                // Process all entries sequentially
                // Transition depends on valid_in and entry_cnt
                if (valid_in && (entry_cnt < num_entries)) begin
                    next_state = SEARCH;
                end else if (entry_cnt >= num_entries) begin
                    next_state = FIND_MAX;
                end else begin
                    next_state = ACCUMULATE;
                end
            end

            SEARCH: begin
                // Look for match or empty slot
                // Go to update when done searching
                next_state = ACCUMULATE;
            end

            FIND_MAX: begin
                // Scan all valid entries for maximum
                // We need 8 cycles to check all slots
                if (idx < 4'b1000) begin
                    next_state = FIND_MAX; // Keep scanning
                end else begin
                    next_state = DONE;
                end
            end

            DONE: begin
                next_state = IDLE; // Wait for next start
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset register file
            for (i = 0; i < 8; i = i + 1) begin
                reg_names[i] <= 64'b0;
                reg_totals[i] <= 10'sd0;
            end
            valid_mask <= 8'b0;
            
            // Reset outputs
            result_name <= 64'b0;
            result_total <= 10'sd0;
            done <= 1'b0;
            error <= 1'b0;
            
            // Reset internal vars
            entry_cnt <= 3'b0;
            idx <= 3'b0;
            max_idx <= 3'b0;
            max_total <= 10'sd0;
            found_match <= 1'b0;
            found_empty <= 1'b0;
            empty_idx <= 3'b0;
            
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    error <= 1'b0;
                    if (start) begin
                        entry_cnt <= 3'b0;
                        idx <= 3'b0;
                        // Initialize max_total to smallest possible signed value
                        max_total <= 10'sd -512; 
                        if (num_entries == 3'b000) begin
                            error <= 1'b1;
                        end
                    end
                end

                ACCUMULATE: begin
                    // Wait for valid input if we haven't finished processing
                    if (valid_in && (entry_cnt < num_entries)) begin
                        idx <= 3'b0;
                        found_match <= 1'b0;
                        found_empty <= 1'b0;
                        empty_idx <= 3'b0; // Reset, will find first empty if needed
                    end
                    // Increment entry count after SEARCH is done (handled in SEARCH state logic via flags)
                end

                SEARCH: begin
                    // Check current index
                    if (valid_mask[idx]) begin
                        // Entry is valid, check name match
                        if (reg_names[idx] == name_in) begin
                            // Match found
                            new_total = reg_totals[idx] + { {2{marks_in[7]}}, marks_in }; // Sign extend 8 to 10 bit
                            reg_totals[idx] <= new_total;
                            found_match <= 1'b1;
                        end
                    end else begin
                        // Empty slot
                        if (!found_empty) begin
                            empty_idx <= idx;
                            found_empty <= 1'b1;
                        end
                    end
                    
                    // Increment index to continue search (if not 7 yet)
                    if (idx < 3'b111) begin
                        idx <= idx + 1'b1;
                    end else begin
                        // End of search, check results
                        if (!found_match && found_empty) begin
                            // Create new entry
                            reg_names[empty_idx] <= name_in;
                            reg_totals[empty_idx] <= { {2{marks_in[7]}}, marks_in };
                            valid_mask[empty_idx] <= 1'b1;
                        end
                        // Increment processed count
                        entry_cnt <= entry_cnt + 1'b1;
                        // Reset index for next accumulate cycle if needed
                        idx <= 3'b0;
                    end
                end

                FIND_MAX: begin
                    // Iterate through all 8 slots (idx 0 to 7)
                    if (idx < 4'b1000) begin
                        if (valid_mask[idx]) begin
                            if (reg_totals[idx] > max_total) begin
                                max_total <= reg_totals[idx];
                                max_idx <= idx;
                            end
                        end
                        idx <= idx + 1'b1;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    if (!error) begin // Only update results if not error
                        result_name <= reg_names[max_idx];
                        result_total <= max_total;
                    end
                end
            endcase
        end
    end

endmodule