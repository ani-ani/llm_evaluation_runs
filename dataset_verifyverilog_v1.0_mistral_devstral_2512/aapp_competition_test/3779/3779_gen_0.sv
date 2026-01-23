module DigitGenerator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [15:0] denominations [0:7],
    input wire [4:0] k,
    output reg [4:0] count,
    output reg [4:0] remainders [0:31],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE_GCD = 3'd1;
    localparam [2:0] GENERATE_SET = 3'd2;
    localparam [2:0] OUTPUT = 3'd3;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // GCD computation variables
    reg [15:0] gcd_a, gcd_b, gcd_temp;
    reg [15:0] current_gcd;
    reg [3:0] denom_index;

    // Set generation variables
    reg [4:0] set_index;
    reg [15:0] multiplier;
    reg [4:0] remainder;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            cycle_count <= 8'd0;
            count <= 5'd0;
            done <= 1'b0;

            // Initialize remainders array
            integer i;
            for (i = 0; i < 32; i = i + 1) begin
                remainders[i] <= 5'd0;
            end

            // Initialize GCD computation variables
            gcd_a <= 16'd0;
            gcd_b <= 16'd0;
            gcd_temp <= 16'd0;
            current_gcd <= 16'd0;
            denom_index <= 4'd0;

            // Initialize set generation variables
            set_index <= 5'd0;
            multiplier <= 16'd0;
            remainder <= 5'd0;
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;

            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= COMPUTE_GCD;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                COMPUTE_GCD: begin
                    // Initialize GCD with first denomination
                    if (denom_index == 4'd0) begin
                        current_gcd <= denominations[0];
                        denom_index <= denom_index + 4'd1;
                    end else if (denom_index < n) begin
                        // Compute GCD of current_gcd and next denomination
                        gcd_a <= current_gcd;
                        gcd_b <= denominations[denom_index];

                        // Euclidean algorithm
                        if (gcd_b == 16'd0) begin
                            current_gcd <= gcd_a;
                            denom_index <= denom_index + 4'd1;
                        end else begin
                            gcd_temp <= gcd_a % gcd_b;
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_temp;
                        end
                    end else begin
                        // Compute GCD with k
                        gcd_a <= current_gcd;
                        gcd_b <= k;

                        if (gcd_b == 16'd0) begin
                            current_gcd <= gcd_a;
                            next_state <= GENERATE_SET;
                        end else begin
                            gcd_temp <= gcd_a % gcd_b;
                            gcd_a <= gcd_b;
                            gcd_b <= gcd_temp;
                        end
                    end
                end

                GENERATE_SET: begin
                    // Generate set: { (i * g) % k for i = 0 to (k/g - 1) }
                    if (set_index == 5'd0) begin
                        // Initialize
                        multiplier <= 16'd0;
                        remainder <= 5'd0;
                        count <= 5'd0;
                    end else if (set_index < (k / current_gcd)) begin
                        // Compute remainder
                        remainder <= (multiplier * current_gcd) % k;
                        remainders[set_index] <= remainder;
                        multiplier <= multiplier + 16'd1;
                        set_index <= set_index + 5'd1;
                        count <= count + 5'd1;
                    end else begin
                        next_state <= OUTPUT;
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