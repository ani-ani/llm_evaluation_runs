module odd_equivalent (
    input clk,
    input rst_n,
    input start,
    input [7:0] s,
    input [3:0] n,
    output reg [3:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam ROTATING = 2'b01;
    localparam COUNTING = 2'b10;
    localparam DONE = 2'b11;

    reg [1:0] current_state, next_state;
    reg [3:0] count_reg, next_count; // counts rotations processed (0 to n-1)
    reg [3:0] result_reg, next_result; // counts valid odd parity rotations
    reg [7:0] temp_s_reg, next_temp_s; // holds the rotated string
    reg parity; // wire for parity check

    // State register and synchronous reset
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            count_reg <= 4'b0;
            result_reg <= 4'b0;
            temp_s_reg <= 8'b0;
        end else begin
            current_state <= next_state;
            count_reg <= next_count;
            result_reg <= next_result;
            temp_s_reg <= next_temp_s;
        end
    end

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        next_state = current_state;
        next_count = count_reg;
        next_result = result_reg;
        next_temp_s = temp_s_reg;
        done = 1'b0;
        result = 4'b0;
        parity = 1'b0;

        // Parity calculation (XOR reduction)
        parity = temp_s_reg[0] ^ temp_s_reg[1] ^ temp_s_reg[2] ^ temp_s_reg[3] ^ 
                 temp_s_reg[4] ^ temp_s_reg[5] ^ temp_s_reg[6] ^ temp_s_reg[7];

        case (current_state)
            IDLE: begin
                done = 1'b0;
                result = 4'b0;
                next_count = 4'b0;
                next_result = 4'b0;
                if (start) begin
                    // Initialize first rotation (rotation 0: original string)
                    next_temp_s = s;
                    if (n == 0) begin
                        next_state = DONE;
                    end else begin
                        next_state = COUNTING; // Go to counting directly for rotation 0
                    end
                end
            end

            COUNTING: begin
                // Check parity of current rotation
                if (parity) begin
                    next_result = result_reg + 1;
                end else begin
                    next_result = result_reg;
                end

                // Prepare for next rotation
                if (count_reg < n - 1) begin
                    next_count = count_reg + 1;
                    next_temp_s = {temp_s_reg[6:0], temp_s_reg[7]}; // Rotate left by 1
                    next_state = ROTATING; // Go to rotating state to simulate delay/pipeline
                end else begin
                    // All rotations processed
                    next_state = DONE;
                end
            end

            ROTATING: begin
                // This state represents the delay for rotation generation
                // We simply transition back to COUNTING
                // The temp_s_reg was already updated in COUNTING state logic
                next_state = COUNTING;
            end

            DONE: begin
                done = 1'b1;
                result = result_reg;
                if (!start) begin
                    // Wait for start to go low to return to IDLE (optional, good practice)
                    // Or just stay here until reset. 
                    // Usually, stays in DONE until reset.
                    // To allow re-trigger without reset:
                    // next_state = IDLE; // Uncomment if falling edge of start triggers idle
                end
                // Explicitly stay in DONE until reset or explicit transition logic
                next_state = DONE; 
                // Handling transition back to IDLE on start falling edge
                if (!start) begin
                   next_state = IDLE;
                   next_count = 4'b0;
                   next_result = 4'b0;
                   next_temp_s = 8'b0;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule
