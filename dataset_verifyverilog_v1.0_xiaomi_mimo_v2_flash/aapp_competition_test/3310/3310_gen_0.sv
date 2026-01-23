module restaurant_expected (
    input clk,
    input rst_n,
    input start,
    input [7:0] n,
    input [7:0] g,
    input [7:0] t,
    input [7:0] c0,
    input [7:0] c1,
    input [7:0] c2,
    input [7:0] c3,
    output reg [15:0] sum_occupancy,
    output reg [15:0] count_sequences,
    output reg done
);

    // Parameters
    localparam [7:0] CAP_WIDTH = 8'd8;
    localparam [7:0] DATA_WIDTH = 8'd16;
    localparam [7:0] MAX_N = 4'd4;
    localparam [7:0] MAX_G = 4'd4;
    localparam [7:0] MAX_T = 4'd4;
    localparam [7:0] MAX_SEQ = 8'd256; // g^t max = 4^4 = 256
    localparam [7:0] MAX_CYCLES = 8'd200; // Safety limit per sequence

    // State Machine States
    localparam [3:0] IDLE = 4'd0;
    localparam [3:0] INIT = 4'd1;
    localparam [3:0] SORT = 4'd2;
    localparam [3:0] NEXT_SEQ = 4'd3;
    localparam [3:0] DECODE_HOURS = 4'd4;
    localparam [3:0] FIND_TABLE = 4'd5;
    localparam [3:0] UPDATE_OCC = 4'd6;
    localparam [3:0] NEXT_HOUR = 4'd7;
    localparam [3:0] ACCUMULATE = 4'd8;
    localparam [3:0] DONE_STATE = 4'd9;

    // Internal Registers
    reg [3:0] state, next_state;
    reg [15:0] sum_occ_reg, next_sum_occ;
    reg [15:0] count_seq_reg, next_count_seq;
    reg [7:0] seq_idx, next_seq_idx; // Current sequence index
    reg [7:0] hour_idx, next_hour_idx; // Current hour index
    reg [7:0] table_idx, next_table_idx; // Current table index for search
    reg [7:0] group_size, next_group_size; // Current group size for hour
    reg [7:0] sorted_cap [0:3]; // Sorted capacities
    reg [7:0] is_occupied [0:3]; // 1 if table is occupied
    reg [7:0] group_size_arr [0:3]; // Decoded group sizes for current sequence
    reg [7:0] cycle_count, next_cycle_count;
    reg [3:0] sort_i, next_sort_i;
    reg [3:0] sort_j, next_sort_j;
    reg temp_cap, next_temp_cap;
    reg [1:0] temp_occupied, next_temp_occupied;
    reg found_table, next_found_table;
    reg [15:0] temp_sum, next_temp_sum;

    integer i;

    // Combinational next state logic
    always @(*) begin
        next_state = state;
        next_sum_occ = sum_occ_reg;
        next_count_seq = count_seq_reg;
        next_seq_idx = seq_idx;
        next_hour_idx = hour_idx;
        next_table_idx = table_idx;
        next_group_size = group_size;
        next_cycle_count = cycle_count;
        next_sort_i = sort_i;
        next_sort_j = sort_j;
        next_temp_cap = temp_cap;
        next_temp_occupied = temp_occupied;
        next_found_table = found_table;
        next_temp_sum = temp_sum;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = INIT;
                end
            end

            INIT: begin
                // Initialize sorted capacities
                // We will sort in SORT state
                next_sort_i = 4'd0;
                next_sort_j = 4'd0;
                next_state = SORT;
            end

            SORT: begin
                // Bubble sort network for 4 elements (combinational style)
                // Using loops for synthesis efficiency
                if (sort_i < n - 1) begin
                    if (sort_j < n - sort_i - 1) begin
                        if (sorted_cap[sort_j] > sorted_cap[sort_j + 1]) begin
                            // Swap
                            next_temp_cap = sorted_cap[sort_j];
                            sorted_cap[sort_j] = sorted_cap[sort_j + 1];
                            sorted_cap[sort_j + 1] = next_temp_cap;
                        end
                        next_sort_j = sort_j + 4'd1;
                    end else begin
                        next_sort_j = 4'd0;
                        next_sort_i = sort_i + 4'd1;
                    end
                end else begin
                    // Initialize sequence index and total occupancy
                    next_seq_idx = 8'd0;
                    next_sum_occ = 16'd0;
                    next_count_seq = 16'd0;
                    // Initialize occupied flags
                    for (i = 0; i < 4; i = i + 1) begin
                        is_occupied[i] = 4'd0;
                    end
                    next_state = NEXT_SEQ;
                end
            end

            NEXT_SEQ: begin
                // Check if all sequences processed
                if (seq_idx >= (g ** t)) begin
                    next_state = DONE_STATE;
                end else begin
                    // Reset hour index and temporary sum for this sequence
                    next_hour_idx = 4'd0;
                    next_temp_sum = 16'd0;
                    // Reset occupied status for new sequence
                    for (i = 0; i < 4; i = i + 1) begin
                        is_occupied[i] = 4'd0;
                    end
                    next_state = DECODE_HOURS;
                end
            end

            DECODE_HOURS: begin
                // Decode group size for current hour based on base-g representation
                // group_size_arr[hour_idx] = (seq_idx / g^hour_idx) % g
                // Simplified: use a counter
                // For synthesis, we calculate group size based on seq_idx and hour_idx
                // A simple way: (seq_idx / (g ** hour_idx)) % g
                // Since g, t are small, we can compute this manually or use a property
                // Let's use: sequence represents a number in base g
                // Hour 0 is least significant digit
                // This is hard to implement synthetically without division
                // Alternative: Pre-calculate or use a counter structure
                
                // Let's use a lookup or calculation
                // Since g is small (2-4), we can calculate powers of g
                reg [7:0] div_factor;
                div_factor = 8'd1;
                for (i = 0; i < hour_idx; i = i + 1) begin
                    div_factor = div_factor * g;
                end
                
                // Use combinational block logic (not loop for synthesis)
                // Actually, let's just use the sequence index directly
                // to generate group sizes in FIND_TABLE using modulo operations
                // But Verilog doesn't support dynamic modulo easily in always blocks
                // We will use a state variable to track the group size extraction
                
                // We will calculate group size for the current hour
                // Group size = (seq_idx / (g ** hour_idx)) % g
                // Since g, t <= 4, g**hour_idx is small
                next_group_size = 8'd0;
                reg [7:0] pow_g;
                pow_g = 8'd1;
                for (i = 0; i < hour_idx; i = i + 1) begin
                    pow_g = pow_g * g;
                end
                
                if (t > 0) begin
                    next_group_size = (seq_idx / pow_g) % g;
                end
                
                next_table_idx = 4'd0; // Start search from first table
                next_found_table = 1'b0;
                next_state = FIND_TABLE;
            end

            FIND_TABLE: begin
                if (table_idx < n) begin
                    // Check if table is empty and has sufficient capacity
                    // Note: We need to check if capacity is sufficient for group size
                    // Table sizes are stored in sorted_cap
                    // We need to track which tables are occupied in the current simulation
                    // Since we don't track which table corresponds to which original index easily
                    // We simply search for the smallest empty table with sufficient capacity
                    // Note: sorted_cap contains sorted capacities, indices are sorted order
                    
                    if ((is_occupied[table_idx] == 4'd0) && (sorted_cap[table_idx] >= group_size)) begin
                        next_found_table = 1'b1;
                        // Mark occupied
                        is_occupied[table_idx] = 4'd1;
                        // Update temporary sum
                        next_temp_sum = temp_sum + group_size;
                        next_state = NEXT_HOUR;
                    end else begin
                        next_table_idx = table_idx + 4'd1;
                    end
                end else begin
                    // No table found, group leaves, no occupancy added
                    next_state = NEXT_HOUR;
                end
            end

            NEXT_HOUR: begin
                next_hour_idx = hour_idx + 4'd1;
                if (hour_idx + 4'd1 >= t) begin
                    // All hours processed for this sequence
                    next_state = ACCUMULATE;
                end else begin
                    next_state = DECODE_HOURS;
                end
            end

            ACCUMULATE: begin
                // Add this sequence's total occupancy to sum
                next_sum_occ = sum_occ_reg + temp_sum;
                next_count_seq = count_seq_reg + 16'd1;
                next_seq_idx = seq_idx + 8'd1;
                next_state = NEXT_SEQ;
            end

            DONE_STATE: begin
                // Done signal handled in sequential logic
                if (start) begin
                    next_state = INIT; // Allow restart
                end else begin
                    next_state = IDLE;
                end
            end

            default: next_state = IDLE;
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sum_occupancy <= 16'd0;
            count_sequences <= 16'd0;
            done <= 1'b0;
            seq_idx <= 8'd0;
            hour_idx <= 8'd0;
            table_idx <= 8'd0;
            group_size <= 8'd0;
            cycle_count <= 8'd0;
            sort_i <= 4'd0;
            sort_j <= 4'd0;
            temp_cap <= 8'd0;
            temp_occupied <= 2'd0;
            found_table <= 1'b0;
            temp_sum <= 16'd0;
            
            // Initialize arrays
            sorted_cap[0] <= 8'd0;
            sorted_cap[1] <= 8'd0;
            sorted_cap[2] <= 8'd0;
            sorted_cap[3] <= 8'd0;
            is_occupied[0] <= 4'd0;
            is_occupied[1] <= 4'd0;
            is_occupied[2] <= 4'd0;
            is_occupied[3] <= 4'd0;
        end else begin
            state <= next_state;
            sum_occupancy <= next_sum_occ;
            count_sequences <= next_count_seq;
            seq_idx <= next_seq_idx;
            hour_idx <= next_hour_idx;
            table_idx <= next_table_idx;
            group_size <= next_group_size;
            cycle_count <= next_cycle_count;
            sort_i <= next_sort_i;
            sort_j <= next_sort_j;
            temp_cap <= next_temp_cap;
            temp_occupied <= next_temp_occupied;
            found_table <= next_found_table;
            temp_sum <= next_temp_sum;

            // Handle INIT state loading of capacities
            if (state == INIT) begin
                sorted_cap[0] <= c0;
                sorted_cap[1] <= c1;
                sorted_cap[2] <= c2;
                sorted_cap[3] <= c3;
            end

            // Done signal logic
            if (state == DONE_STATE && next_state == IDLE) begin
                done <= 1'b1;
            end else if (start && next_state == INIT) begin
                done <= 1'b0; // Clear done on new start
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule