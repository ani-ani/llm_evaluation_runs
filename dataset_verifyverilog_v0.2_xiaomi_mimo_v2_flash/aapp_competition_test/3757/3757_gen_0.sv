module subsequence_counter (
    input clk,
    input rst_n,
    input start,
    input [15:0] a00,
    input [15:0] a01,
    input [15:0] a10,
    input [15:0] a11,
    output reg done,
    output reg valid,
    output reg [15:0] length,
    input [7:0] result_index,
    output reg result_bit
);

    // State definitions
    localparam IDLE = 4'd0;
    localparam CALC_N0 = 4'd1;
    localparam CALC_N1 = 4'd2;
    localparam CHECK_CONSISTENCY = 4'd3;
    localparam CALC_PARAMS = 4'd4;
    localparam CONSTRUCT_STRING = 4'd5;
    localparam FINISH = 4'd6;

    // Registers for inputs and computed values
    reg [15:0] r_a00, r_a01, r_a10, r_a11;
    reg [15:0] n0, n1;
    reg [15:0] k, r, n0_minus_k;
    
    // Loop counters
    reg [7:0] i; // Counter for various loops
    reg [7:0] j; // Counter for result construction

    // Result Buffer (64-bit shift register as requested)
    // We will store bits in MSB-first order for easier extraction
    reg [63:0] result_buffer;

    // FSM State register
    reg [3:0] state;

    // Combinational logic for finding n0 and n1
    // We use a simple iterative solver since max value is small (255)
    reg [7:0] candidate;
    reg [15:0] calculated_pairs;
    wire [15:0] target_val;
    wire target_is_a00;

    // Helper logic to determine which value we are solving for
    // We route the target signal based on state
    assign target_val = (state == CALC_N0) ? r_a00 : r_a11;
    assign target_is_a00 = (state == CALC_N0);

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            valid <= 0;
            length <= 0;
            result_bit <= 0;
            result_buffer <= 64'd0;
            i <= 0;
            j <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    valid <= 0;
                    if (start) begin
                        r_a00 <= a00;
                        r_a01 <= a01;
                        r_a10 <= a10;
                        r_a11 <= a11;
                        state <= CALC_N0;
                        i <= 0; // Use i as the candidate for n
                    end
                end

                CALC_N0: begin
                    // Solve n*(n-1)/2 = target for n0
                    // Iterate i from 0 to 255
                    calculated_pairs <= (i > 0) ? (i * (i - 1)) >> 1 : 0;
                    
                    if (i > 255) begin
                        // Should not happen if inputs are consistent, but fail safe
                        state <= FINISH;
                        valid <= 0;
                    end else if (calculated_pairs == target_val) begin
                        n0 <= i;
                        state <= CALC_N1;
                        i <= 0; // Reset for N1 calc
                    end else begin
                        i <= i + 1;
                    end
                end

                CALC_N1: begin
                    // Solve n*(n-1)/2 = target for n1
                    calculated_pairs <= (i > 0) ? (i * (i - 1)) >> 1 : 0;
                    
                    if (i > 255) begin
                        state <= FINISH;
                        valid <= 0;
                    end else if (calculated_pairs == target_val) begin
                        n1 <= i;
                        state <= CHECK_CONSISTENCY;
                    end else begin
                        i <= i + 1;
                    end
                end

                CHECK_CONSISTENCY: begin
                    // Verify n0 * n1 == a01 + a10
                    if (n0 * n1 == (r_a01 + r_a10)) begin
                        state <= CALC_PARAMS;
                    end else begin
                        state <= FINISH;
                        valid <= 0;
                    end
                end

                CALC_PARAMS: begin
                    // Calculate k = a01 / n1, r = a01 % n1
                    // Handle n1 = 0 case to avoid division by zero
                    if (n1 == 0) begin
                        if (r_a01 == 0) begin
                            k <= 0;
                            r <= 0;
                            state <= CONSTRUCT_STRING;
                        end else begin
                            state <= FINISH;
                            valid <= 0;
                        end
                    end else begin
                        k <= r_a01 / n1;
                        r <= r_a01 % n1;
                        state <= CONSTRUCT_STRING;
                        j <= 0; // j will count how many '0's we have processed
                        result_buffer <= 64'd0;
                    end
                end

                CONSTRUCT_STRING: begin
                    // Pattern: k copies of '01', then '0' + r '1's, then (n0-k-1) '0's, then rest '1's
                    // We build the buffer by shifting in MSB first (or just store array style)
                    // Let's assume we append bits to the buffer. Since it's a register, we need to shift or calculate indices.
                    // Given small size (64 bits), we can write directly to indices.
                    
                    // To avoid complex combinational indexing in logic, we'll use a sequential process
                    // to populate the buffer.
                    
                    // We'll use 'i' as the position in the result string
                    // We'll use 'j' as the count of '0's placed so far
                    
                    // Optimization: Calculate total length first
                    // Length = (2*k) + 1 + r + (n0 - k - 1) + (n1 - k - r) ? No, simpler.
                    // Length = n0 + n1.
                    length <= n0 + n1;

                    // We need to fill result_buffer bit by bit. 
                    // Let's interpret the instructions for construction:
                    // 1. k copies of '01': Sequence of k '0's followed by k '1's (interleaved)
                    // 2. 1 copy of '0' followed by r '1's
                    // 3. (n0 - k - 1) copies of '0'
                    // 4. Remaining '1's

                    // We will use a secondary state inside this main state or just iterate.
                    // Since we have a flat FSM, we'll use 'i' as position and control flow.
                    
                    // Let's break down construction into sub-steps using 'state' or nested logic.
                    // To keep state count low, we will use 'i' and logic blocks.
                    
                    if (i < (n0 + n1)) begin
                        // Determine bit at position i
                        // This is tricky to do in one cycle efficiently without LUTs.
                        // Let's use the provided formula description directly:
                        // "k copies of '01'"
                        // "1 copy of '0' followed by r '1's"
                        // "(n0 - k - 1) copies of '0'"
                        // "remaining '1's"
                        
                        // Let's calculate which region we are in:
                        // Region 0: 0 to 2*k-1 (k pairs of '01') -> bit is 0 if even, 1 if odd
                        // Region 1: 2*k (single '0') -> bit 0
                        // Region 2: 2*k+1 to 2*k+r ('1's) -> bit 1
                        // Region 3: 2*k+1+r to n0+n1-1 (remaining '0's then '1's)
                        //   Remaining '0's count: n0 - k - 1
                        //   Remaining '1's count: n1 - k - r
                        
                        // Actually, the description is:
                        // string = (01)*k + 0 + (1)*r + (0)*(n0-k-1) + (1)*(n1-k-r)
                        // Wait, the description says: "k copies of '01', then 1 copy of '0' followed by r '1's, then (n0 - k - 1) copies of '0', then remaining '1's"
                        // This implies a sequence:
                        // [0,1] repeated k times -> length 2k
                        // [0] -> length 1
                        // [1] repeated r times -> length r
                        // [0] repeated (n0-k-1) times -> length (n0-k-1)
                        // [1] repeated (n1 - k - r) times -> length (n1 - k - r)
                        // Total length = 2k + 1 + r + (n0-k-1) + (n1-k-r) = n0 + n1. Correct.

                        // We need to output bit by bit. We can pre-calculate the sequence in the buffer.
                        // Since we can't use a loop in combinational logic easily for synthesis to be "efficient",
                        // we will populate the buffer sequentially over multiple cycles.
                        // We will use a sub-counter 'i' to track the bit position being written.
                        
                        // We will use a separate state to fill the buffer, or fill it while 'i' increments.
                        // To do this in one state, we need to update 'result_buffer' and 'i' every cycle.
                        
                        // Logic for bit at current position 'i' (0-indexed):
                        reg bit_val;
                        bit_val = 0; // Default
                        
                        if (i < 2 * k) begin
                            // Region 0: '01' pairs
                            bit_val = (i[0] == 0) ? 1'b0 : 1'b1;
                        end else if (i == 2 * k) begin
                            // Region 1: Single '0'
                            bit_val = 1'b0;
                        end else if (i < 2 * k + 1 + r) begin
                            // Region 2: r '1's (after the single '0')
                            // Note: i starts at 2*k + 1 here effectively because of the else if chain
                            // The check is `i < 2*k + 1 + r`.
                            // If i = 2*k+1, it enters here.
                            bit_val = 1'b1;
                        end else if (i < 2 * k + 1 + r + (n0 - k - 1)) begin
                            // Region 3: Remaining '0's
                            bit_val = 1'b0;
                        end else begin
                            // Region 4: Remaining '1's
                            bit_val = 1'b1;
                        end

                        // Update buffer: Shift in new bit or set directly.
                        // Since we want to read later by index, let's store it at index 'i'.
                        // We cannot index a 64-bit register directly with a variable in synthesis easily for writing.
                        // We will shift the buffer and append. Then we must reverse it on read, OR
                        // we just accept that the MSB of the register corresponds to the start of the string.
                        // Let's shift MSB first. 
                        // result_buffer <= {result_buffer[62:0], bit_val};
                        // This puts bit 0 at position 63 (MSB). 
                        // Read logic: result_bit = result_buffer[63 - result_index];
                        
                        result_buffer <= {result_buffer[62:0], bit_val};
                        i <= i + 1;
                    end else begin
                        // Buffer filled
                        state <= FINISH;
                        valid <= 1;
                    end
                end

                FINISH: begin
                    done <= 1;
                    if (!start) begin // Wait for start to go low to reset or allow new start
                        state <= IDLE;
                        done <= 0;
                        valid <= 0;
                        i <= 0;
                    end
                end
            endcase
        end
    end

    // Read logic (Combinational)
    // Result buffer stores string in MSB first order (bit 0 is MSB).
    // result_index 0 should read the first bit.
    always @(*) begin
        if (state == FINISH && done && valid) begin
            // Check bounds
            if (result_index < (n0 + n1) && result_index < 64) begin
                result_bit = result_buffer[63 - result_index];
            end else begin
                result_bit = 0; // Default out of bounds
            end
        end else begin
            result_bit = 0;
        end
    end

endmodule
