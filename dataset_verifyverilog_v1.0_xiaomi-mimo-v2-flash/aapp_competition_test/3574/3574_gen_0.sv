module magical_subarray (
    input clk,
    input rst_n,
    input start,
    input [2:0] query_l,
    input [2:0] query_r,
    input [7:0] array_data,
    input [2:0] array_addr,
    input array_wr,
    output reg [3:0] result,
    output reg done,
    output reg [2:0] state
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOADING    = 3'd1;
    localparam [2:0] PROCESSING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Internal RAM for array storage (8x8-bit)
    reg [7:0] array_reg [0:7];

    // Processing registers
    reg [2:0] l_query, r_query;        // Store query boundaries
    reg [2:0] i, j;                     // Loop counters for subarray bounds
    reg [7:0] first_val, last_val;      // First and last values of subarray
    reg [3:0] current_length;           // Current subarray length
    reg [3:0] max_length;               // Maximum magical length found
    reg magical_flag;                   // Flag if current subarray is magical
    reg [2:0] k;                        // Inner loop counter for checking elements
    reg loading_done;                   // Flag for array loading completion
    reg [3:0] cycle_count;              // Cycle counter for timeout
    localparam [3:0] MAX_CYCLES = 4'd12; // Max cycles per query (8 elements + overhead)

    // Output assignments for debug state
    always @(*) begin
        state = (rst_n == 1'b0) ? IDLE : state_reg;
    end

    // Main state register
    reg [2:0] state_reg;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state_reg <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            l_query <= 3'd0;
            r_query <= 3'd0;
            i <= 3'd0;
            j <= 3'd0;
            first_val <= 8'd0;
            last_val <= 8'd0;
            current_length <= 4'd0;
            max_length <= 4'd0;
            magical_flag <= 1'b0;
            k <= 3'd0;
            loading_done <= 1'b0;
            cycle_count <= 4'd0;
        end else begin
            case (state_reg)
                IDLE: begin
                    done <= 1'b0;
                    loading_done <= 1'b0;
                    cycle_count <= 4'd0;
                    
                    // Handle array loading
                    if (array_wr) begin
                        array_reg[array_addr] <= array_data;
                        loading_done <= 1'b1;
                    end
                    
                    // Handle query start
                    if (start && loading_done) begin
                        l_query <= query_l;
                        r_query <= query_r;
                        i <= query_l;
                        j <= query_l;
                        max_length <= 4'd0;
                        state_reg <= PROCESSING;
                        cycle_count <= 4'd0;
                    end
                end
                
                PROCESSING: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Initialize subarray check for new (i,j) pair
                    if (j == i) begin
                        // Single element is always magical
                        current_length <= 4'd1;
                        magical_flag <= 1'b1;
                        k <= i;
                        first_val <= array_reg[i];
                        last_val <= array_reg[j];
                    end else if (j > i && k == i) begin
                        // Start checking elements for subarray (i,j)
                        first_val <= array_reg[i];
                        last_val <= array_reg[j];
                        magical_flag <= 1'b1;
                        current_length <= j - i + 4'd1;
                        // Check next element
                        if (i + 3'd1 <= j) begin
                            if (array_reg[i + 3'd1] < array_reg[i] || array_reg[i + 3'd1] > array_reg[j]) begin
                                magical_flag <= 1'b0;
                            end
                            k <= i + 3'd2;
                        end
                    end else if (k <= j && k > i) begin
                        // Continue checking elements
                        if (magical_flag) begin
                            if (array_reg[k] < first_val || array_reg[k] > last_val) begin
                                magical_flag <= 1'b0;
                            end
                        end
                        k <= k + 3'd1;
                    end else if (k > j) begin
                        // Done checking this subarray
                        if (magical_flag) begin
                            if (current_length > max_length) begin
                                max_length <= current_length;
                            end
                        end
                        
                        // Move to next subarray
                        if (j < r_query) begin
                            j <= j + 3'd1;
                            k <= i; // Reset for next subarray check
                        end else begin
                            j <= i + 3'd1;
                            if (i < r_query) begin
                                i <= i + 3'd1;
                            end else begin
                                // All subarrays processed
                                result <= max_length;
                                state_reg <= DONE_STATE;
                            end
                        end
                    end
                    
                    // Timeout protection
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= max_length;
                        state_reg <= DONE_STATE;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                    state_reg <= IDLE;
                end
                
                default: begin
                    state_reg <= IDLE;
                end
            endcase
        end
    end

endmodule