module tuple_grouping (
    input clk,
    input rst_n,
    input start,
    input [1:0] tuple_first [0:3],
    input [1:0] tuple_second [0:3],
    output reg [1:0] group_first [0:3],
    output reg [1:0] group_data [0:15],
    output reg [2:0] group_size [0:3],
    output reg [1:0] num_groups,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam FIND_UNIQUE = 3'b001;
    localparam COLLECT_DATA = 3'b010;
    localparam FORMAT_OUTPUT = 3'b011;
    localparam DONE_STATE = 3'b100;

    reg [2:0] state, next_state;
    reg [1:0] unique_keys [0:3];
    reg [1:0] unique_count;
    reg [1:0] current_key;
    reg [2:0] process_idx; // Index for input tuple processing
    reg [2:0] output_idx;  // Index for output writing
    reg [1:0] group_idx;   // Current group being processed
    reg [3:0] data_offset; // Offset in group_data
    reg [1:0] temp_second; // Temporary storage for second element
    
    // Helper variables
    integer i, j;
    reg key_found;
    reg [1:0] match_idx;

    // State transition
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
                if (start)
                    next_state = FIND_UNIQUE;
                else
                    next_state = IDLE;
            end
            FIND_UNIQUE: begin
                // Process 4 input tuples (4 cycles)
                if (process_idx >= 4)
                    next_state = COLLECT_DATA;
                else
                    next_state = FIND_UNIQUE;
            end
            COLLECT_DATA: begin
                // Process groups: 4 groups max, 4 elements max each
                // We use a counter approach, transition when all done
                // Check if we processed all unique keys and all their matching elements
                if (group_idx >= unique_count && process_idx >= 4)
                    next_state = FORMAT_OUTPUT;
                else
                    next_state = COLLECT_DATA;
            end
            FORMAT_OUTPUT: begin
                // 1 cycle to format offsets/sizes
                next_state = DONE_STATE;
            end
            DONE_STATE: begin
                // Stay in done for 1 cycle, then back to idle
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset outputs
            for (i = 0; i < 4; i = i + 1) begin
                group_first[i] <= 0;
                group_size[i] <= 0;
            end
            for (i = 0; i < 16; i = i + 1) begin
                group_data[i] <= 0;
            end
            num_groups <= 0;
            done <= 0;
            
            // Reset internal regs
            unique_count <= 0;
            process_idx <= 0;
            output_idx <= 0;
            group_idx <= 0;
            data_offset <= 0;
            current_key <= 0;
            for (i = 0; i < 4; i = i + 1)
                unique_keys[i] <= 0;
        end else begin
            done <= 0; // Default done low
            
            case (state)
                IDLE: begin
                    if (start) begin
                        // Reset outputs on start
                        for (i = 0; i < 4; i = i + 1) begin
                            group_first[i] <= 0;
                            group_size[i] <= 0;
                        end
                        for (i = 0; i < 16; i = i + 1) begin
                            group_data[i] <= 0;
                        end
                        num_groups <= 0;
                        
                        // Reset counters
                        unique_count <= 0;
                        process_idx <= 0;
                        output_idx <= 0;
                        group_idx <= 0;
                        data_offset <= 0;
                        for (i = 0; i < 4; i = i + 1)
                            unique_keys[i] <= 0;
                    end
                end

                FIND_UNIQUE: begin
                    // Parallel comparison logic simulation over 4 cycles
                    // Check if tuple_first[process_idx] exists in unique_keys
                    key_found = 0;
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < unique_count && unique_keys[i] == tuple_first[process_idx]) begin
                            key_found = 1;
                        end
                    end
                    
                    if (!key_found && unique_count < 4 && process_idx < 4) begin
                        unique_keys[unique_count] <= tuple_first[process_idx];
                        unique_count <= unique_count + 1;
                    end
                    
                    if (process_idx < 4)
                        process_idx <= process_idx + 1;
                end

                COLLECT_DATA: begin
                    // Logic: Iterate through unique_keys (group_idx) and input tuples (process_idx)
                    // We effectively perform a nested loop: 
                    // Outer loop: group_idx (current unique key)
                    // Inner loop: process_idx (scan inputs for matches)
                    
                    if (group_idx < unique_count) begin
                        // If we have finished scanning inputs for this group key
                        if (process_idx >= 4) begin
                            // Move to next group
                            group_idx <= group_idx + 1;
                            process_idx <= 0;
                        end else begin
                            // Check match
                            if (tuple_first[process_idx] == unique_keys[group_idx]) begin
                                // Found match, write to output
                                if (output_idx < 16) begin
                                    group_data[output_idx] <= tuple_second[process_idx];
                                    output_idx <= output_idx + 1;
                                    // Increment size for this group (tracked via output logic later or temp reg)
                                    // Actually, group_size needs to be updated. 
                                    // Since we need to store size per group, let's update group_size directly.
                                    group_size[group_idx] <= group_size[group_idx] + 1;
                                end
                            end
                            process_idx <= process_idx + 1;
                        end
                    end
                end

                FORMAT_OUTPUT: begin
                    // Assign group_first from unique keys
                    // Calculate offsets if needed (implicit by data order, but we need to set group_first)
                    for (i = 0; i < 4; i = i + 1) begin
                        if (i < unique_count) begin
                            group_first[i] <= unique_keys[i];
                        end else begin
                            group_first[i] <= 0;
                        end
                    end
                    num_groups <= unique_count;
                end

                DONE_STATE: begin
                    done <= 1;
                end
            endcase
        end
    end

endmodule
