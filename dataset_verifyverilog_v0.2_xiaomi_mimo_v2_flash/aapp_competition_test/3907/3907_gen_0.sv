module max_payout (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [11:0] num_n,
    input wire [7:0] num_m,
    input wire [15:0] weights [0:99],
    output reg [31:0] max_sum,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam CALC = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state;
    reg [5:0] k; // Counter for distinct integers (up to 64)
    reg [31:0] sum;
    reg [11:0] required;
    reg [11:0] n_reg;
    reg [7:0] m_reg;

    // Next state logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            max_sum <= 32'b0;
            done <= 1'b0;
            k <= 6'b0;
            sum <= 32'b0;
            required <= 12'b0;
            n_reg <= 12'b0;
            m_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= CALC;
                        k <= 6'd1; // Start with k=1
                        sum <= 32'b0;
                        n_reg <= num_n;
                        m_reg <= num_m;
                        // Pre-calculate required for k=1
                        // k=1 (odd): (1*0)/2 + 1 = 1
                        required <= 12'd1;
                    end
                end

                CALC: begin
                    // Check if current k is valid within bounds
                    if (k > m_reg) begin
                        state <= DONE;
                        max_sum <= sum;
                    end else begin
                        // Check condition: required <= n_reg
                        if (required <= n_reg) begin
                            // Add weight. weights is 0-indexed, so use k-1
                            // k is up to 64, so k-1 fits in index 99
                            sum <= sum + weights[k - 1];
                        end

                        // Update k and pre-calculate required for next k
                        k <= k + 1;

                        // Calculate required size for next k (k+1)
                        // Logic separated based on parity of next k
                        // Note: k is current k, next k is k+1
                        if ((k + 1) % 2 == 1) begin // Next k is odd
                            // required = ((k+1) * k) / 2 + 1
                            // Let next_k = k + 1
                            // required = (next_k * (next_k - 1)) / 2 + 1
                            // To avoid wide multiplication, we can use current k logic
                            // Current k logic: required = (k*(k-1))/2 + 1 (if odd) or (k*k)/2 (if even)
                            // Let's just compute directly for next k to avoid confusion
                            // Next k is k+1. Let's call it next_k
                            // If next_k is odd: (next_k * (next_k-1))/2 + 1
                            // Since next_k is odd, next_k-1 is even. Division is exact.
                            required <= ((k + 1) * k) >> 1 + 1;
                        end else begin // Next k is even
                            // required = (next_k * next_k) / 2
                            // Since next_k is even, division is exact.
                            required <= ((k + 1) * (k + 1)) >> 1;
                        end
                    end
                end

                DONE: begin
                    if (!start) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule