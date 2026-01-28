module speedrun_optimizer(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [5:0] m_in,
    input wire [12:0] n_in,
    input wire [12:0] r_in,
    input wire [12:0] t_in [0:49],
    input wire [31:0] p_in [0:49],
    input wire [10:0] d_in [0:49],
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Fixed-point constants
    localparam [31:0] SCALE = 32'd65536; // Q16.16 scale factor
    localparam [31:0] ONE = 32'd65536;   // 1.0 in Q16.16

    // Internal registers
    reg [1:0] state;
    reg [5:0] i_reg;           // Current trick index
    reg [31:0] E_next;         // E[i+1] value
    reg [31:0] E_current;      // E[i] value
    reg [31:0] remaining;      // remaining = n - t[i]
    reg [31:0] T_cont;         // T_cont = (remaining + E[i+1]) / p[i]
    reg [31:0] T_reset;        // T_reset = d[i] + t[i]
    reg [31:0] p_inv;          // 1/p[i] in Q16.16
    reg [31:0] temp_mult;      // Temporary for multiplication
    reg [63:0] mult_result;    // 64-bit multiplication result
    reg [31:0] div_result;     // Division result
    reg [7:0] cycle_count;     // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd1000;

    // Newton-Raphson division for 1/p
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i_reg <= 6'd0;
            E_next <= 32'd0;
            E_current <= 32'd0;
            remaining <= 32'd0;
            T_cont <= 32'd0;
            T_reset <= 32'd0;
            p_inv <= 32'd0;
            temp_mult <= 32'd0;
            mult_result <= 64'd0;
            div_result <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        i_reg <= m_in - 6'd1; // Start from m-1
                        E_next <= {n_in, 16'd0}; // E[m] = n (Q16.16)
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute remaining = n - t[i]
                    remaining <= {n_in, 16'd0} - {t_in[i_reg], 16'd0};

                    // Compute T_reset = d[i] + t[i]
                    T_reset <= {d_in[i_reg], 16'd0} + {t_in[i_reg], 16'd0};

                    // Compute T_cont = (remaining + E[i+1]) / p[i]
                    // First compute numerator: (remaining + E[i+1])
                    temp_mult <= remaining + E_next;

                    // Compute 1/p[i] using Newton-Raphson (approximation)
                    // Initial guess: p_inv = (3 - p[i]) / 2
                    p_inv <= (32'd196608 - p_in[i_reg]) / 2;

                    // Multiply numerator by p_inv
                    mult_result <= temp_mult * p_inv;
                    T_cont <= mult_result[47:16]; // Take middle 32 bits

                    // Choose minimal
                    if (T_cont <= T_reset) begin
                        E_current <= T_cont;
                    end else begin
                        E_current <= T_reset;
                    end

                    // Move to next iteration
                    if (i_reg == 6'd0) begin
                        state <= FINISH;
                        result <= E_current;
                    end else begin
                        i_reg <= i_reg - 6'd1;
                        E_next <= E_current;
                    end

                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= IDLE;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule