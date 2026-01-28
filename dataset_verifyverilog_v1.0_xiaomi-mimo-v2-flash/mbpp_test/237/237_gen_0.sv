module tuple_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [255:0] tuples_in,
    input wire [3:0] num_tuples,
    output reg result_valid,
    output reg [15:0] result_tuple,
    output reg [7:0] result_count,
    output reg done
);

    // Parameters
    localparam [3:0] MAX_TUPLES = 4'd16;
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] SORT = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;
    localparam [2:0] DONE = 3'd4;

    // Internal Registers
    reg [2:0] state, next_state;
    reg [3:0] tuple_idx;          // Index for current tuple being processed
    reg [3:0] unique_idx;         // Index for dictionary lookup
    reg [3:0] unique_count;       // Number of unique tuples stored
    reg [3:0] output_idx;         // Index for output iteration
    reg start_dly;                // Delayed start signal for edge detection
    
    // Dictionary Memory (16 entries, 24 bits each: 16-bit key + 8-bit count)
    reg [15:0] dict_key [0:15];
    reg [7:0] dict_count [0:15];
    
    // Sorting Logic Registers
    reg [7:0] a_reg, b_reg;
    reg [15:0] sorted_tuple;
    reg match_found;
    integer i;

    // State Machine Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tuple_idx <= 4'd0;
            unique_idx <= 4'd0;
            unique_count <= 4'd0;
            output_idx <= 4'd0;
            result_valid <= 1'b0;
            result_tuple <= 16'd0;
            result_count <= 8'd0;
            done <= 1'b0;
            start_dly <= 1'b0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            sorted_tuple <= 16'd0;
            match_found <= 1'b0;
            // Initialize dictionary memory
            for (i = 0; i < 16; i = i + 1) begin
                dict_key[i] <= 16'd0;
                dict_count[i] <= 8'd0;
            end
        end else begin
            start_dly <= start;
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    tuple_idx <= 4'd0;
                    unique_idx <= 4'd0;
                    output_idx <= 4'd0;
                    if (start && !start_dly) begin
                        unique_count <= 4'd0;  // Reset unique count on new start
                        state <= SORT;
                    end
                end

                SORT: begin
                    if (tuple_idx < num_tuples) begin
                        // Extract current tuple
                        a_reg <= tuples_in[tuple_idx*16 + 15 +: 8];  // bits 15:8
                        b_reg <= tuples_in[tuple_idx*16 + 7 +: 8];   // bits 7:0
                        
                        // Sorting comparator (combinational)
                        if (a_reg > b_reg) begin
                            sorted_tuple <= {b_reg, a_reg};
                        end else begin
                            sorted_tuple <= {a_reg, b_reg};
                        end
                        
                        state <= COUNT;
                        unique_idx <= 4'd0;
                        match_found <= 1'b0;
                    end else begin
                        state <= OUTPUT;
                        output_idx <= 4'd0;
                    end
                end

                COUNT: begin
                    if (unique_idx < unique_count) begin
                        // Check for match in existing entries
                        if (dict_key[unique_idx] == sorted_tuple) begin
                            // Match found - increment count
                            dict_count[unique_idx] <= dict_count[unique_idx] + 8'd1;
                            match_found <= 1'b1;
                            state <= SORT;  // Return to process next tuple
                            tuple_idx <= tuple_idx + 4'd1;
                        end else begin
                            // No match yet, check next
                            unique_idx <= unique_idx + 4'd1;
                        end
                    end else begin
                        // End of dictionary, no match found
                        if (!match_found && unique_count < MAX_TUPLES) begin
                            // Add new entry
                            dict_key[unique_count] <= sorted_tuple;
                            dict_count[unique_count] <= 8'd1;
                            unique_count <= unique_count + 4'd1;
                        end
                        state <= SORT;
                        tuple_idx <= tuple_idx + 4'd1;
                    end
                end

                OUTPUT: begin
                    if (output_idx < unique_count) begin
                        result_tuple <= dict_key[output_idx];
                        result_count <= dict_count[output_idx];
                        result_valid <= 1'b1;
                        output_idx <= output_idx + 4'd1;
                        // Stay in OUTPUT for next cycle (result_valid pulses)
                    end else begin
                        result_valid <= 1'b0;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule