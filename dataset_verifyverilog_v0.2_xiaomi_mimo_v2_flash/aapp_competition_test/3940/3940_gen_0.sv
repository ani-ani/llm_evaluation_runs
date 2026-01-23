module array_specializer (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire query_valid,
    input wire [2:0] l_i,
    input wire [2:0] r_i,
    output reg [2:0] min_mex,
    output reg [2:0] array_out,
    output reg output_valid,
    output reg done
);

    // Parameters
    parameter M = 4;          // Number of queries
    parameter N = 8;          // Number of elements

    // State Encoding
    localparam IDLE = 2'b00;
    localparam READ_QUERIES = 2'b01;
    localparam OUTPUT = 2'b10;

    // Internal Registers and Wires
    reg [1:0] current_state, next_state;
    reg [2:0] current_min_length;
    reg [2:0] next_min_length;
    reg [1:0] query_count;
    reg [1:0] next_query_count;
    reg [3:0] output_count;     // Counts 0 to N-1 (N=8, so 4 bits to be safe)
    reg [3:0] next_output_count;
    reg [2:0] pattern_index;    // Index in the pattern 0 to min_length-1
    reg [2:0] next_pattern_index;

    // Logic for Subarray Length Calculation
    wire [2:0] sub_len;
    assign sub_len = r_i - l_i + 1;

    // State Register and Synchronous Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            current_min_length <= 3'b111; // Max possible value (7) so min can decrease
            query_count <= 2'b00;
            output_count <= 4'b0000;
            pattern_index <= 3'b000;
        end else begin
            current_state <= next_state;
            current_min_length <= next_min_length;
            query_count <= next_query_count;
            output_count <= next_output_count;
            pattern_index <= next_pattern_index;
        end
    end

    // Next State and Output Logic (Combinational)
    always @(*) begin
        // Default assignments to avoid latches
        next_state = current_state;
        next_min_length = current_min_length;
        next_query_count = query_count;
        next_output_count = output_count;
        next_pattern_index = pattern_index;
        
        min_mex = 3'b000;
        array_out = 3'b000;
        output_valid = 1'b0;
        done = 1'b0;

        case (current_state)
            IDLE: begin
                if (start) begin
                    next_state = READ_QUERIES;
                    next_min_length = 3'b111; // Reset to max (7) for new calculation
                    next_query_count = 2'b00;
                end
            end

            READ_QUERIES: begin
                if (query_valid) begin
                    // Update min length: if current calculated length is smaller than stored, keep smaller
                    if (sub_len < current_min_length) begin
                        next_min_length = sub_len;
                    end else begin
                        next_min_length = current_min_length;
                    end
                    
                    next_query_count = query_count + 1;
                    
                    // Check if all M queries are done (M=4, so count goes 0->3)
                    if (query_count == M - 1) begin
                        next_state = OUTPUT;
                        next_output_count = 4'b0000;
                        next_pattern_index = 3'b000;
                    end else begin
                        next_state = READ_QUERIES;
                    end
                end else begin
                    // Hold values if query not valid
                    next_min_length = current_min_length;
                    next_query_count = query_count;
                end
            end

            OUTPUT: begin
                done = 1'b1;
                
                // Output valid when we are in OUTPUT state
                output_valid = 1'b1;
                
                // Assign outputs based on current state/registers
                min_mex = current_min_length;
                array_out = pattern_index;
                
                // Update counters for next cycle
                next_output_count = output_count + 1;
                
                // Handle Pattern Index
                if (pattern_index == (current_min_length - 1)) begin
                    next_pattern_index = 3'b000;
                end else begin
                    next_pattern_index = pattern_index + 1;
                end
                
                // Check for completion (N cycles generated)
                // N=8, so count goes 0..7. When count is 7, next cycle will be 8.
                if (output_count == N - 1) begin
                    // Stop generating, go back to IDLE or stay done?
                    // Requirement: "Done high when all queries processed and array generation starts"
                    // Usually done remains high for one cycle or until reset. Let's deassert done and go to IDLE.
                    next_state = IDLE;
                    next_output_count = 4'b0000;
                end else begin
                    next_state = OUTPUT;
                end
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule
