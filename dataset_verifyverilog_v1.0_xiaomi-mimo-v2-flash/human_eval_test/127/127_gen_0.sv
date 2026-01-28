module prime_intersection_checker (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [7:0] s1,
    input wire signed [7:0] e1,
    input wire signed [7:0] s2,
    input wire signed [7:0] e2,
    output reg result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] LOAD = 3'd1;
    localparam [2:0] COMPUTE = 3'd2;
    localparam [2:0] CHECK = 3'd3;
    localparam [2:0] OUTPUT_STATE = 3'd4;
    localparam [2:0] FINISH = 3'd5;

    // Registers for latched inputs
    reg signed [7:0] latched_s1;
    reg signed [7:0] latched_e1;
    reg signed [7:0] latched_s2;
    reg signed [7:0] latched_e2;

    // Combinational intermediate values
    wire signed [7:0] intersect_start;
    wire signed [7:0] intersect_end;
    wire signed [7:0] raw_length;
    wire [5:0] length; // Unsigned integer length (0-32)
    wire [4:0] length_addr; // Address for LUT (0-31)

    // LUT for prime check (0-31)
    // 1 = prime, 0 = non-prime
    reg [31:0] prime_lut;

    // State registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] cycle_count; // Prevent infinite loops (max 10 cycles)

    // Compute max and min
    // max(s1, s2)
    assign intersect_start = (latched_s1 > latched_s2) ? latched_s1 : latched_s2;
    // min(e1, e2)
    assign intersect_end = (latched_e1 < latched_e2) ? latched_e1 : latched_e2;

    // Length computation
    assign raw_length = intersect_end - intersect_start;
    // Length is valid only if intersect_start <= intersect_end
    // raw_length is signed, convert to unsigned clamped at 0
    // Check for negative result
    wire intersection_valid;
    assign intersection_valid = (intersect_start <= intersect_end);
    
    // Length clamped to 0 if invalid, otherwise raw_length (which is 0-32)
    // raw_length is signed, so we cast/clamp carefully
    assign length = intersection_valid ? (raw_length[5:0]) : 6'd0;

    // Address for LUT (5 bits, 0-31)
    assign length_addr = length[4:0];

    // Prime Check Combinational Logic
    wire is_prime;
    reg is_prime_reg;

    // Look up length in LUT (if length <= 31)
    // If length == 32, it's not prime (handled separately)
    always @(*) begin
        if (length <= 31) begin
            is_prime_reg = prime_lut[length_addr];
        end else begin
            is_prime_reg = 1'b0; // 32 is not prime
        end
    end

    // Initialize LUT
    // Indices: 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
    // Values:  0 0 1 1 0 1 0 1 0 0 0  1  0  1  0  0  0  1  0  1  0  0  0  1  0  0  0  0  0  1  0  1
    // Bit order is LSB = index 0
    // Bit 31 (LUT[31]) = 1 (31 is prime)
    // Bit 2 (LUT[2]) = 1 (2 is prime)
    initial begin
        prime_lut = 32'b10100001000010100100000100001011;
    end

    // FSM Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 1'b0;
            latched_s1 <= 8'sd0;
            latched_e1 <= 8'sd0;
            latched_s2 <= 8'sd0;
            latched_e2 <= 8'sd0;
            cycle_count <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= LOAD;
                        // Latch inputs immediately
                        latched_s1 <= s1;
                        latched_e1 <= e1;
                        latched_s2 <= s2;
                        latched_e2 <= e2;
                    end
                end

                LOAD: begin
                    // Move to compute state
                    state <= COMPUTE;
                end

                COMPUTE: begin
                    // Combinational logic calculates length
                    // Wait 1 cycle for logic to settle
                    // Also increment cycle count
                    cycle_count <= cycle_count + 4'd1;
                    state <= CHECK;
                end

                CHECK: begin
                    // Read is_prime_reg
                    // Check timeout
                    if (cycle_count > 10) begin
                        // Timeout - go to finish with error
                        result <= 1'b0;
                        state <= FINISH;
                    end else begin
                        // Valid result
                        result <= is_prime_reg;
                        state <= OUTPUT_STATE;
                    end
                end

                OUTPUT_STATE: begin
                    // Set done signal
                    done <= 1'b1;
                    state <= FINISH;
                end

                FINISH: begin
                    // Deassert done and return to IDLE
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end

endmodule