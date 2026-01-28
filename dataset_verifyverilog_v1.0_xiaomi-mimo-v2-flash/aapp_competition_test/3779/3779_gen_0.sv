module compute_last_digits (
    input clk,
    input rst_n,
    input start,
    input [3:0] n,
    input [15:0] a [0:15],
    input [7:0] k_in,
    output reg [7:0] result_count,
    output reg [7:0] result_d [0:15],
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] MOD_OP    = 3'd1;  // Compute a_i % k_in
    localparam [2:0] GCD_OP    = 3'd2;  // Compute GCD
    localparam [2:0] DIV_OP    = 3'd3;  // Compute result_count
    localparam [2:0] GEN_MULT  = 3'd4;  // Generate multiples
    localparam [2:0] FINISH    = 3'd5;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd32;
    
    // Internal registers
    reg [7:0] g_temp;
    reg [7:0] g_final;
    reg [3:0] idx;
    reg [7:0] mult_val;
    reg [7:0] div_rem;
    reg [7:0] div_count;
    reg div_done;
    reg gcd_calc_busy;
    reg [7:0] gcd_a, gcd_b;
    wire [7:0] gcd_result;
    wire gcd_busy;
    wire gcd_valid;

    // GCD Module (iterative, 8-bit)
    gcd_8bit gcd_inst (
        .clk(clk),
        .rst_n(rst_n),
        .start(gcd_calc_busy),
        .a(gcd_a),
        .b(gcd_b),
        .result(gcd_result),
        .busy(gcd_busy),
        .valid(gcd_valid)
    );

    // Main FSM
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result_count <= 8'd0;
            for (int i = 0; i < 16; i = i + 1) begin
                result_d[i] <= 8'd0;
            end
            done <= 1'b0;
            cycle_count <= 8'd0;
            g_temp <= 8'd0;
            g_final <= 8'd0;
            idx <= 4'd0;
            mult_val <= 8'd0;
            div_rem <= 8'd0;
            div_count <= 8'd0;
            div_done <= 1'b0;
            gcd_calc_busy <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    result_count <= 8'd0;
                    for (int i = 0; i < 16; i = i + 1) begin
                        result_d[i] <= 8'd0;
                    end
                    if (start) begin
                        g_temp <= k_in;
                        idx <= 4'd0;
                        state <= MOD_OP;
                    end
                end

                MOD_OP: begin
                    if (idx < n) begin
                        // Compute a[idx] % k_in
                        // Using repeated subtraction for safety or direct mod if k_in fits
                        // Given k_in <= 128, a[idx] <= 16 bit, direct mod is fine logic-wise
                        // But to avoid wide math, let's use the property: a[i] % k is safe with 16 bits
                        // However, we need gcd with k, so ensure k is in range.
                        // g_temp is k initially.
                        
                        // Start GCD computation for (g_temp, a[idx] % k_in)
                        // We need the modulus result first. Simple mod logic:
                        // Since k_in <= 128, a[i] is 16-bit. 16-bit mod 8-bit is standard.
                        gcd_a <= g_temp;
                        gcd_b <= a[idx][7:0] % k_in; // Reduce 16-bit to 8-bit mod
                        gcd_calc_busy <= 1'b1;
                        state <= GCD_OP;
                    end else begin
                        // Done with all denominations
                        g_final <= g_temp;
                        idx <= 4'd0; // Reset for DIV_OP or GEN_MULT
                        state <= DIV_OP;
                    end
                end

                GCD_OP: begin
                    if (gcd_valid) begin
                        g_temp <= gcd_result;
                        gcd_calc_busy <= 1'b0;
                        idx <= idx + 4'd1;
                        state <= MOD_OP;
                    end
                end

                DIV_OP: begin
                    // Compute result_count = k_in / g_final
                    // g_final is >= 1. k_in is <= 128.
                    // Simple repeated subtraction
                    if (!div_done) begin
                        if (div_rem < g_final) begin
                            div_done <= 1'b1;
                            result_count <= div_count;
                            // Prepare for generation
                            mult_val <= 8'd0;
                            idx <= 4'd0;
                            state <= GEN_MULT;
                        end else begin
                            div_rem <= div_rem - g_final;
                            div_count <= div_count + 8'd1;
                        end
                    end else begin
                        // Reset div registers for next time
                        div_rem <= k_in;
                        div_count <= 8'd0;
                        div_done <= 1'b0;
                    end
                end

                GEN_MULT: begin
                    if (idx < result_count) begin
                        result_d[idx] <= mult_val;
                        mult_val <= mult_val + g_final;
                        idx <= idx + 4'd1;
                    end else begin
                        // Pad remaining slots with 0 (already 0 from reset, but ensure if generated logic changes)
                        // Actually, result_d is cleared in IDLE, so unused slots remain 0.
                        cycle_count <= cycle_count + 8'd1;
                        if (cycle_count >= MAX_CYCLES) begin // Safety timer or specific wait
                             state <= FINISH;
                        end else begin
                            // Check if we are done generating
                             state <= FINISH;
                        end
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

module gcd_8bit (
    input clk,
    input rst_n,
    input start,
    input [7:0] a,
    input [7:0] b,
    output reg [7:0] result,
    output reg busy,
    output reg valid
);
    localparam [1:0] G_IDLE = 2'd0;
    localparam [1:0] G_CALC = 2'd1;
    localparam [1:0] G_DONE = 2'd2;
    
    reg [1:0] state;
    reg [7:0] x, y;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= G_IDLE;
            result <= 8'd0;
            busy <= 1'b0;
            valid <= 1'b0;
            x <= 8'd0;
            y <= 8'd0;
        end else begin
            case (state)
                G_IDLE: begin
                    valid <= 1'b0;
                    if (start) begin
                        x <= a;
                        y <= b;
                        busy <= 1'b1;
                        state <= G_CALC;
                    end
                end
                G_CALC: begin
                    if (y == 8'd0) begin
                        result <= x;
                        state <= G_DONE;
                        busy <= 1'b0;
                    end else begin
                        x <= y;
                        y <= x % y;
                    end
                end
                G_DONE: begin
                    valid <= 1'b1;
                    state <= G_IDLE;
                end
                default: state <= G_IDLE;
            endcase
        end
    end
endmodule