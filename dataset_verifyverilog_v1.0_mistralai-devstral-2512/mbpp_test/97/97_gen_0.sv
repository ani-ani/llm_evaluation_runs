module FreqCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] lists [0:3][0:3],
    output reg [3:0] result_val [0:7],
    output reg [3:0] result_cnt [0:7],
    output reg [3:0] result_count,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FLATTEN = 3'd1;
    localparam [2:0] COUNT   = 3'd2;
    localparam [2:0] OUTPUT  = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Flattened array
    reg [3:0] flat [0:15];
    reg [3:0] flat_index;

    // Counting variables
    reg [3:0] current_val;
    reg [3:0] search_index;
    reg found;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            flat_index <= 4'd0;
            current_val <= 4'd0;
            search_index <= 3'd0;
            found <= 1'b0;
            done <= 1'b0;
            result_count <= 4'd0;

            // Initialize all outputs
            integer i;
            for (i = 0; i < 8; i = i + 1) begin
                result_val[i] <= 4'd0;
                result_cnt[i] <= 4'd0;
            end

            // Initialize flattened array
            for (i = 0; i < 16; i = i + 1) begin
                flat[i] <= 4'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FLATTEN;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FLATTEN: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Flatten the 2D array
                    reg [1:0] row, col;
                    row = flat_index[3:2];
                    col = flat_index[1:0];
                    flat[flat_index] <= lists[row][col];
                    
                    flat_index <= flat_index + 4'd1;
                    
                    if (flat_index == 4'd16) begin
                        flat_index <= 4'd0;
                        next_state <= COUNT;
                    end else begin
                        next_state <= FLATTEN;
                    end
                end

                COUNT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current value to process
                    current_val <= flat[flat_index];
                    
                    // Search for value in result_val
                    found <= 1'b0;
                    search_index <= 3'd0;
                    
                    // Check if value already exists
                    integer j;
                    for (j = 0; j < result_count; j = j + 1) begin
                        if (result_val[j] == current_val) begin
                            found <= 1'b1;
                            search_index <= j;
                        end
                    end
                    
                    // Update counts
                    if (found) begin
                        result_cnt[search_index] <= result_cnt[search_index] + 4'd1;
                    end else if (result_count < 8) begin
                        result_val[result_count] <= current_val;
                        result_cnt[result_count] <= 4'd1;
                        result_count <= result_count + 4'd1;
                    end
                    
                    flat_index <= flat_index + 4'd1;
                    
                    if (flat_index == 4'd16 || cycle_count >= MAX_CYCLES) begin
                        flat_index <= 4'd0;
                        next_state <= OUTPUT;
                    end else begin
                        next_state <= COUNT;
                    end
                end

                OUTPUT: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end
endmodule