module perfect_sets (
    input clk,
    input rst_n,
    input start,
    input [15:0] k,
    output reg [31:0] result,
    output reg done
);

    // Parameters
    parameter MOD = 32'd1000000007;

    // State Encoding
    localparam IDLE = 2'b00;
    localparam PROCESS_BIT = 2'b01;
    localparam COMPUTE_DONE = 2'b10;

    // State Registers
    reg [1:0] current_state, next_state;

    // DP Registers and Wires
    reg [31:0] dp_tight [0:16];
    reg [31:0] dp_loose [0:16];
    reg [31:0] next_dp_tight [0:16];
    reg [31:0] next_dp_loose [0:16];

    // Iteration counter
    reg [4:0] bit_idx;

    // Control signals
    wire [15:0] k_reversed;
    assign k_reversed = k;

    // Next state logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
        end else begin
            current_state <= next_state;
        end
    end

    // Next State and Output Logic
    always @(*) begin
        next_state = current_state; // Default hold
        case (current_state)
            IDLE: begin
                if (start) next_state = PROCESS_BIT;
            end
            PROCESS_BIT: begin
                if (bit_idx == 5'd0) next_state = COMPUTE_DONE; // Processed bit 0, next cycle done
                else next_state = PROCESS_BIT;
            end
            COMPUTE_DONE: begin
                next_state = IDLE; // Self-reset or wait for next start
            end
        endcase
    end

    // Datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 0;
            done <= 0;
            bit_idx <= 15;
            dp_tight[0] <= 1;
            dp_loose[0] <= 0;
            for (int i = 1; i < 17; i = i + 1) begin
                dp_tight[i] <= 0;
                dp_loose[i] <= 0;
            end
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Initialize DP
                        // Initial state: tight=1, basis_count=0, sum=1 (empty set)
                        dp_tight[0] <= 1;
                        dp_loose[0] <= 0;
                        bit_idx <= 15; // Start at MSB
                    end
                end

                PROCESS_BIT: begin
                    // DP Update Logic per bit i (15 down to 0)
                    // Logic based on tight/loose transitions.
                    for (int d = 0; d < 17; d = d + 1) begin
                        next_dp_tight[d] <= 0;
                        next_dp_loose[d] <= 0;
                    end
                    if (k_reversed[bit_idx]) begin
                        // k[i] == 1
                        for (int d = 0; d < 17; d = d + 1) begin
                            next_dp_tight[d] <= dp_tight[d] * 2^d;
                            next_dp_loose[d] <= dp_loose[d] * 2^d;
                            next_dp_loose[d + 1] <= dp_tight[d];
                        end
                    end else begin
                        // k[i] == 0
                        for (int d = 0; d < 17; d = d + 1) begin
                            next_dp_tight[d] <= dp_tight[d];
                            next_dp_loose[d] <= dp_loose[d] * 2^d;
                        end
                    end
                    // Update DP registers
                    dp_tight <= next_dp_tight;
                    dp_loose <= next_dp_loose;
                    bit_idx <= bit_idx - 1;
                end

                COMPUTE_DONE: begin
                    // Sum up all dp_tight and dp_loose
                    result <= 0;
                    for (int d = 0; d < 17; d = d + 1) begin
                        result <= result + dp_tight[d] + dp_loose[d];
                    end
                    done <= 1;
                end
            endcase
        end
    end
endmodule