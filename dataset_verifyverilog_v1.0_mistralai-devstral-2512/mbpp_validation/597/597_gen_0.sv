module kth_element_finder(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr1_in,
    input wire [7:0] arr2_in,
    output reg [3:0] arr1_addr,
    output reg [3:0] arr2_addr,
    input wire [3:0] arr1_len,
    input wire [3:0] arr2_len,
    input wire [4:0] k,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] FETCH   = 3'd1;
    localparam [2:0] COMPARE = 3'd2;
    localparam [2:0] MERGE   = 3'd3;
    localparam [2:0] COMPLETE = 3'd4;

    reg [2:0] state, next_state;

    // Pointers and counters
    reg [4:0] i_ptr;      // Pointer for arr1
    reg [4:0] j_ptr;      // Pointer for arr2
    reg [4:0] d_ptr;      // Pointer for merged array
    reg [4:0] k_index;    // k-1 for 0-based indexing

    // Internal merged array (32 x 8-bit)
    reg [7:0] merged_array [0:31];

    // Temporary storage for current elements
    reg [7:0] current_arr1;
    reg [7:0] current_arr2;

    // Cycle counter for timeout
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd255;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            i_ptr <= 5'd0;
            j_ptr <= 5'd0;
            d_ptr <= 5'd0;
            k_index <= 5'd0;
            arr1_addr <= 4'd0;
            arr2_addr <= 4'd0;
            result <= 8'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;

            // Initialize merged array
            integer idx;
            for (idx = 0; idx < 32; idx = idx + 1) begin
                merged_array[idx] <= 8'd0;
            end
        end else begin
            state <= next_state;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= FETCH;
                        k_index <= k - 5'd1;  // Convert to 0-based
                        i_ptr <= 5'd0;
                        j_ptr <= 5'd0;
                        d_ptr <= 5'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                FETCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        // Request current elements
                        arr1_addr <= i_ptr[3:0];
                        arr2_addr <= j_ptr[3:0];
                        current_arr1 <= arr1_in;
                        current_arr2 <= arr2_in;
                        next_state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (cycle_count >= MAX_CYCLES) begin
                        next_state <= IDLE;
                    end else begin
                        // Check if we've exhausted either array
                        if (i_ptr >= arr1_len && j_ptr >= arr2_len) begin
                            next_state <= COMPLETE;
                        end else if (i_ptr >= arr1_len) begin
                            // Copy remaining from arr2
                            merged_array[d_ptr] <= current_arr2;
                            j_ptr <= j_ptr + 5'd1;
                            d_ptr <= d_ptr + 5'd1;
                            next_state <= FETCH;
                        end else if (j_ptr >= arr2_len) begin
                            // Copy remaining from arr1
                            merged_array[d_ptr] <= current_arr1;
                            i_ptr <= i_ptr + 5'd1;
                            d_ptr <= d_ptr + 5'd1;
                            next_state <= FETCH;
                        end else begin
                            // Compare and merge
                            if (current_arr1 <= current_arr2) begin
                                merged_array[d_ptr] <= current_arr1;
                                i_ptr <= i_ptr + 5'd1;
                            end else begin
                                merged_array[d_ptr] <= current_arr2;
                                j_ptr <= j_ptr + 5'd1;
                            end
                            d_ptr <= d_ptr + 5'd1;
                            next_state <= FETCH;
                        end
                    end
                end

                COMPLETE: begin
                    result <= merged_array[k_index];
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