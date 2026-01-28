module xor_sequence_counter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] n_in,
    input wire [15:0] m_in,
    output reg [31:0] result,
    output reg done
);

    // Constants
    localparam [31:0] MODULUS = 32'd1000000009;

    // States
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] CALCULATING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [31:0] product;
    reg [31:0] p;
    reg [31:0] term;
    reg [3:0] i;
    reg [31:0] temp_mult;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            product <= 32'd0;
            p <= 32'd0;
            term <= 32'd0;
            i <= 4'd0;
            temp_mult <= 32'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Calculate p = 2^m mod MODULUS
                        if (m_in == 16'd0) begin
                            p <= 32'd1;
                        end else begin
                            p <= 32'd1 << m_in;
                            if (p >= MODULUS) begin
                                p <= p % MODULUS;
                            end
                        end

                        // Initialize product = (p - 1) mod MODULUS
                        if (p == 32'd0) begin
                            product <= MODULUS - 32'd1;
                        end else begin
                            product <= p - 32'd1;
                        end

                        // Handle n=0 case
                        if (n_in == 16'd0) begin
                            result <= 32'd1;
                            done <= 1'b1;
                            state <= DONE_STATE;
                        end else begin
                            i <= 4'd0;
                            state <= CALCULATING;
                        end
                    end
                end

                CALCULATING: begin
                    // Calculate term = (p - 1 - i) mod MODULUS
                    if (p > i) begin
                        term <= p - 32'd1 - i;
                    end else begin
                        term <= (p - 32'd1 - i) + MODULUS;
                    end

                    // Multiply: product = (product * term) mod MODULUS
                    temp_mult <= product * term;
                    if (temp_mult >= MODULUS) begin
                        product <= temp_mult % MODULUS;
                    end else begin
                        product <= temp_mult;
                    end

                    // Increment counter
                    i <= i + 4'd1;

                    // Check if done
                    if (i == n_in - 16'd1) begin
                        result <= product;
                        done <= 1'b1;
                        state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule