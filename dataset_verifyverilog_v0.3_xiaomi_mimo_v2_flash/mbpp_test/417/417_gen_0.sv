module module_spec_tuple_grouping (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] input_pairs [0:7],
    input wire [3:0] valid_count,
    output reg [7:0] output_groups [0:7],
    output reg [3:0] group_counts [0:7],
    output reg done,
    output reg result_valid
);

    // State definitions
    localparam [3:0] IDLE      = 4'd0;
    localparam [3:0] READ      = 4'd1;
    localparam [3:0] CHECK     = 4'd2;
    localparam [3:0] ACCUM     = 4'd3;
    localparam [3:0] STORE_NEW = 4'd4;
    localparam [3:0] DONE      = 4'd5;

    reg [3:0] state, next_state;
    reg [3:0] input_index;
    reg [3:0] group_index;
    reg [3:0] groups_found;
    reg [7:0] temp_groups [0:7];
    reg [3:0] temp_counts [0:7];
    reg [3:0] current_first;
    reg [3:0] current_second;
    reg match_found;
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd128;

    // Internal signals for loop indices
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            input_index <= 4'd0;
            group_index <= 4'd0;
            groups_found <= 4'd0;
            current_first <= 4'd0;
            current_second <= 4'd0;
            match_found <= 1'b0;
            cycle_counter <= 8'd0;
            done <= 1'b0;
            result_valid <= 1'b0;
            
            // Initialize arrays
            for (i = 0; i < 8; i = i + 1) begin
                output_groups[i] <= 8'd0;
                group_counts[i] <= 4'd0;
                temp_groups[i] <= 8'd0;
                temp_counts[i] <= 4'd0;
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_counter <= 8'd0;
                    groups_found <= 4'd0;
                    input_index <= 4'd0;
                    
                    // Clear temp arrays
                    for (i = 0; i < 8; i = i + 1) begin
                        temp_groups[i] <= 8'd0;
                        temp_counts[i] <= 4'd0;
                    end
                    
                    if (start && valid_count > 4'd0) begin
                        state <= READ;
                    end else begin
                        state <= IDLE;
                    end
                end
                
                READ: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (input_index < valid_count && cycle_counter < MAX_CYCLES) begin
                        // Extract first and second from 8-bit input
                        // {first[3:0], second[3:0]}
                        current_first <= input_pairs[input_index][7:4];
                        current_second <= input_pairs[input_index][3:0];
                        group_index <= 4'd0;
                        match_found <= 1'b0;
                        state <= CHECK;
                    end else if (cycle_counter >= MAX_CYCLES || input_index >= valid_count) begin
                        // Pack outputs from temp arrays
                        for (i = 0; i < 8; i = i + 1) begin
                            output_groups[i] <= temp_groups[i];
                            group_counts[i] <= temp_counts[i];
                        end
                        result_valid <= 1'b1;
                        state <= DONE;
                    end
                end
                
                CHECK: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (cycle_counter >= MAX_CYCLES) begin
                        state <= DONE;
                    end else if (group_index < groups_found) begin
                        // Check if first matches existing group
                        if (temp_groups[group_index][7:4] == current_first) begin
                            match_found <= 1'b1;
                            state <= ACCUM;
                        end else begin
                            group_index <= group_index + 4'd1;
                            state <= CHECK;
                        end
                    end else begin
                        // No match found, need to create new group
                        if (groups_found < 4'd8) begin
                            state <= STORE_NEW;
                        end else begin
                            // Maximum groups reached, skip this input
                            input_index <= input_index + 4'd1;
                            state <= READ;
                        end
                    end
                end
                
                ACCUM: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Update existing group (append second element)
                    // For simplicity, we only keep track of count
                    // Since we can't pack more than 4 bits in value field
                    // we'll increment count as indicator of accumulation
                    temp_counts[group_index] <= temp_counts[group_index] + 4'd1;
                    input_index <= input_index + 4'd1;
                    state <= READ;
                end
                
                STORE_NEW: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    // Store new group with first element and second as value
                    temp_groups[groups_found] <= {current_first, current_second};
                    temp_counts[groups_found] <= 4'd1;
                    groups_found <= groups_found + 4'd1;
                    input_index <= input_index + 4'd1;
                    state <= READ;
                end
                
                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule