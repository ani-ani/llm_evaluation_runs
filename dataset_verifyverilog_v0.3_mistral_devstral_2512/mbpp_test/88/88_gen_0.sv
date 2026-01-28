module ElementFrequencyCounter(
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

    // Lookup table: 16 entries, each with 8-bit key and 8-bit count
    reg [7:0] key_table [0:15];
    reg [7:0] count_table [0:15];

    // State and control signals
    reg [2:0] state, next_state;
    reg [3:0] clear_addr;
    reg [3:0] output_addr;
    reg [7:0] current_key;
    reg found_match;
    reg [3:0] match_index;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            valid_out <= 1'b0;
            key_out <= 8'd0;
            count_out <= 8'd0;
            clear_addr <= 4'd0;
            output_addr <= 4'd0;
            current_key <= 8'd0;
            found_match <= 1'b0;
            match_index <= 4'd0;
            
            // Initialize lookup table
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                key_table[i] <= 8'd0;
                count_table[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CLEAR;
                end
            end
            
            CLEAR: begin
                if (clear_addr == 4'd15) begin
                    next_state = COUNT;
                end
            end
            
            COUNT: begin
                if (done_in) begin
                    next_state = OUTPUT;
                end
            end
            
            OUTPUT: begin
                if (output_addr == 4'd15) begin
                    next_state = COMPLETE;
                end
            end
            
            COMPLETE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Clear phase: Initialize lookup table
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            clear_addr <= 4'd0;
        end else if (state == CLEAR) begin
            key_table[clear_addr] <= 8'd0;
            count_table[clear_addr] <= 8'd0;
            clear_addr <= clear_addr + 4'd1;
        end
    end

    // Count phase: Process input data
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_key <= 8'd0;
            found_match <= 1'b0;
            match_index <= 4'd0;
        end else if (state == COUNT && valid_in) begin
            current_key <= data_in;
            found_match <= 1'b0;
            match_index <= 4'd0;
            
            // Check for existing key in table
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                if (key_table[i] == current_key && count_table[i] != 8'd0) begin
                    found_match <= 1'b1;
                    match_index <= i;
                end
            end
            
            // If found, increment count; else find empty slot
            if (found_match) begin
                count_table[match_index] <= count_table[match_index] + 8'd1;
            end else begin
                // Find first empty slot
                for (i = 0; i < 16; i = i + 1) begin
                    if (count_table[i] == 8'd0) begin
                        key_table[i] <= current_key;
                        count_table[i] <= 8'd1;
                        break;
                    end
                end
            end
        end
    end

    // Output phase: Stream out non-zero entries
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            output_addr <= 4'd0;
            valid_out <= 1'b0;
        end else if (state == OUTPUT) begin
            if (count_table[output_addr] != 8'd0) begin
                key_out <= key_table[output_addr];
                count_out <= count_table[output_addr];
                valid_out <= 1'b1;
            end else begin
                valid_out <= 1'b0;
            end
            output_addr <= output_addr + 4'd1;
        end else begin
            valid_out <= 1'b0;
        end
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else if (state == COMPLETE) begin
            done <= 1'b1;
        end else begin
            done <= 1'b0;
        end
    end

endmodule