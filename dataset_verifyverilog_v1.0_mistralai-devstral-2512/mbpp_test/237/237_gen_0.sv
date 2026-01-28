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

    localparam [3:0] MAX_TUPLES = 4'd16;
    localparam [3:0] MAX_UNIQUE = 4'd16;

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] SORT      = 3'd1;
    localparam [2:0] COUNT     = 3'd2;
    localparam [2:0] OUTPUT    = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    reg [2:0] state, next_state;

    // Internal registers
    reg [3:0] tuple_index;
    reg [3:0] unique_index;
    reg [3:0] search_index;
    reg [3:0] current_unique_count;
    reg [7:0] a_reg, b_reg;
    reg [15:0] sorted_tuple;
    reg found_match;

    // Dictionary memory (16 entries)
    reg [15:0] dict_keys [0:15];
    reg [7:0] dict_counts [0:15];

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tuple_index <= 4'd0;
            unique_index <= 4'd0;
            search_index <= 4'd0;
            current_unique_count <= 4'd0;
            a_reg <= 8'd0;
            b_reg <= 8'd0;
            sorted_tuple <= 16'd0;
            found_match <= 1'b0;
            result_valid <= 1'b0;
            result_tuple <= 16'd0;
            result_count <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize dictionary
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                dict_keys[i] <= 16'd0;
                dict_counts[i] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        tuple_index <= 4'd0;
                        unique_index <= 4'd0;
                        current_unique_count <= 4'd0;
                        next_state <= SORT;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                SORT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Read current tuple
                    a_reg <= tuples_in[(tuple_index * 16) + 15 : (tuple_index * 16) + 8];
                    b_reg <= tuples_in[(tuple_index * 16) + 7 : (tuple_index * 16)];

                    // Sort: if a > b, swap
                    if (a_reg > b_reg) begin
                        sorted_tuple <= {b_reg, a_reg};
                    end else begin
                        sorted_tuple <= {a_reg, b_reg};
                    end

                    // Move to counting state
                    search_index <= 4'd0;
                    found_match <= 1'b0;
                    next_state <= COUNT;
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've found a match
                    if (!found_match && search_index < current_unique_count) begin
                        if (dict_keys[search_index] == sorted_tuple) begin
                            found_match <= 1'b1;
                            dict_counts[search_index] <= dict_counts[search_index] + 8'd1;
                        end
                        search_index <= search_index + 4'd1;
                        next_state <= COUNT;
                    end else if (!found_match && search_index == current_unique_count) begin
                        // No match found, add new entry
                        if (current_unique_count < MAX_UNIQUE) begin
                            dict_keys[current_unique_count] <= sorted_tuple;
                            dict_counts[current_unique_count] <= 8'd1;
                            current_unique_count <= current_unique_count + 4'd1;
                        end
                        
                        // Move to next tuple or output
                        tuple_index <= tuple_index + 4'd1;
                        if (tuple_index < num_tuples) begin
                            next_state <= SORT;
                        end else begin
                            unique_index <= 4'd0;
                            next_state <= OUTPUT;
                        end
                    end else begin
                        // Match was found, move to next tuple or output
                        tuple_index <= tuple_index + 4'd1;
                        if (tuple_index < num_tuples) begin
                            next_state <= SORT;
                        end else begin
                            unique_index <= 4'd0;
                            next_state <= OUTPUT;
                        end
                    end
                end

                OUTPUT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Output current unique tuple
                    result_valid <= 1'b1;
                    result_tuple <= dict_keys[unique_index];
                    result_count <= dict_counts[unique_index];

                    // Move to next entry or finish
                    unique_index <= unique_index + 4'd1;
                    if (unique_index < current_unique_count) begin
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    result_valid <= 1'b0;
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule