module ElementFrequencyCounter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire valid_in,
    input wire done_in,
    output reg [7:0] key_out,
    output reg [7:0] count_out,
    output reg valid_out,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] CLEAR   = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state, next_state;
    reg [3:0] index;          // Index for table operations (0-15)
    reg [3:0] table_index;    // Index for table lookups
    reg [7:0] lookup_key [15:0];    // 16-entry lookup table
    reg [7:0] lookup_count [15:0];  // 16-entry counter table
    reg [3:0] valid_entries;        // Number of valid entries
    reg found;                      // Flag for search
    reg [7:0] cycle_count;          // Cycle counter for timeout
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            key_out <= 8'd0;
            count_out <= 8'd0;
            valid_out <= 1'b0;
            done <= 1'b0;
            index <= 4'd0;
            table_index <= 4'd0;
            valid_entries <= 4'd0;
            found <= 1'b0;
            cycle_count <= 8'd0;
            // Initialize lookup tables
            begin : init_loop
                integer i;
                for (i = 0; i < 16; i = i + 1) begin
                    lookup_key[i] <= 8'd0;
                    lookup_count[i] <= 8'd0;
                end
            end
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    valid_out <= 1'b0;
                    index <= 4'd0;
                    table_index <= 4'd0;
                    valid_entries <= 4'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CLEAR;
                    end
                end

                CLEAR: begin
                    // Clear table entries one by one
                    lookup_key[index] <= 8'd0;
                    lookup_count[index] <= 8'd0;
                    index <= index + 4'd1;
                    if (index == 4'd15) begin
                        state <= COUNT;
                        index <= 4'd0;
                    end
                end

                COUNT: begin
                    if (valid_in) begin
                        // Search for matching key in table
                        found <= 1'b0;
                        table_index <= 4'd0;
                        // Search phase will happen next cycle
                        state <= COUNT;
                    end else if (done_in) begin
                        // Done with input, move to output
                        state <= OUTPUT;
                        index <= 4'd0;
                    end
                end

                OUTPUT: begin
                    // Stream valid entries
                    if (index < valid_entries) begin
                        key_out <= lookup_key[index];
                        count_out <= lookup_count[index];
                        valid_out <= 1'b1;
                        index <= index + 4'd1;
                    end else begin
                        valid_out <= 1'b0;
                        state <= COMPLETE;
                    end
                    cycle_count <= cycle_count + 8'd1;
                end

                COMPLETE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase

            // Search logic for COUNT state
            if (state == COUNT && valid_in && !found) begin
                if (table_index < 4'd16) begin
                    // Check if slot is empty or matches
                    if (lookup_key[table_index] == data_in && lookup_count[table_index] != 8'd0) begin
                        // Found match - increment
                        lookup_count[table_index] <= lookup_count[table_index] + 8'd1;
                        found <= 1'b1;
                    end else if (lookup_count[table_index] == 8'd0) begin
                        // Empty slot - add new entry
                        lookup_key[table_index] <= data_in;
                        lookup_count[table_index] <= 8'd1;
                        valid_entries <= valid_entries + 4'd1;
                        found <= 1'b1;
                    end
                    table_index <= table_index + 4'd1;
                end
            end

            // Timeout protection
            if (cycle_count >= MAX_CYCLES && state != IDLE) begin
                state <= COMPLETE;
            end
        end
    end

endmodule