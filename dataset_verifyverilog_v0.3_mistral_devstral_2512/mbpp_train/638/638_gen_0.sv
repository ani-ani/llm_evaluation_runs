module wind_chill_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire signed [15:0] temp_in,
    input wire [15:0] wind_in,
    output reg signed [15:0] result,
    output reg done
);

    // State declarations
    localparam [3:0] IDLE   = 4'd0;
    localparam [3:0] LOOKUP = 4'd1;
    localparam [3:0] MULT1  = 4'd2;
    localparam [3:0] MULT2  = 4'd3;
    localparam [3:0] MULT3  = 4'd4;
    localparam [3:0] MULT4  = 4'd5;
    localparam [3:0] ACCUM  = 4'd6;
    localparam [3:0] ROUND  = 4'd7;
    localparam [3:0] DONE_STATE = 4'd8;

    // Fixed-point constants (Q16.16 format)
    localparam signed [31:0] CONST_13_12 = 32'h000D1F70;
    localparam signed [31:0] CONST_0_6215 = 32'h00009E5A;
    localparam signed [31:0] CONST_11_37 = 32'h000B5E85;
    localparam signed [31:0] CONST_0_3965 = 32'h0000659F;

    // Lookup table for v^0.16 (Q16.16 format)
    reg signed [31:0] v_pow_0_16_table [0:255];

    // Internal registers
    reg [3:0] state, next_state;
    reg signed [31:0] v_pow_0_16;
    reg signed [31:0] temp_q16_16;
    reg signed [31:0] term1, term2, term3, term4;
    reg signed [31:0] windchill_q16_16;
    reg [7:0] cycle_count;
    reg [7:0] table_index;

    // Initialize lookup table
    integer i;
    initial begin
        // Pre-computed values for v^0.16 in Q16.16 format
        // These values are approximate and should be replaced with actual computed values
        for (i = 0; i < 256; i = i + 1) begin
            v_pow_0_16_table[i] = 32'h00000000; // Placeholder - actual values needed
        end
        // Example values (replace with actual computed values)
        v_pow_0_16_table[0] = 32'h00000000; // 0^0.16 = 0
        v_pow_0_16_table[1] = 32'h0000C000; // ~0.75
        v_pow_0_16_table[2] = 32'h0000D000; // ~0.81
        // ... (fill with actual values)
        v_pow_0_16_table[200] = 32'h00012000; // ~1.125
    end

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            temp_q16_16 <= 32'd0;
            v_pow_0_16 <= 32'd0;
            term1 <= 32'd0;
            term2 <= 32'd0;
            term3 <= 32'd0;
            term4 <= 32'd0;
            windchill_q16_16 <= 32'd0;
        end else begin
            state <= next_state;
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= LOOKUP;
                        // Convert temp_in to Q16.16
                        temp_q16_16 <= {{16{temp_in[15]}}, temp_in};
                        // Get table index from wind_in
                        table_index <= wind_in[7:0];
                    end else begin
                        next_state <= IDLE;
                    end
                end

                LOOKUP: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (wind_in == 16'd0) begin
                        v_pow_0_16 <= 32'd0;
                    end else begin
                        v_pow_0_16 <= v_pow_0_16_table[table_index];
                    end
                    if (cycle_count >= 8'd8) begin
                        next_state <= MULT1;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= LOOKUP;
                    end
                end

                MULT1: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute 0.3965 * temp * v^0.16
                    // First multiply temp * v^0.16
                    term1 <= $signed({temp_q16_16[31:16], temp_q16_16[15:0]} * 
                                   {v_pow_0_16[31:16], v_pow_0_16[15:0]})[47:16];
                    if (cycle_count >= 8'd8) begin
                        next_state <= MULT2;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= MULT1;
                    end
                end

                MULT2: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Multiply by 0.3965
                    term2 <= $signed({term1[31:16], term1[15:0]} * 
                                   {CONST_0_3965[31:16], CONST_0_3965[15:0]})[47:16];
                    if (cycle_count >= 8'd8) begin
                        next_state <= MULT3;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= MULT2;
                    end
                end

                MULT3: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute 0.6215 * temp
                    term3 <= $signed({temp_q16_16[31:16], temp_q16_16[15:0]} * 
                                   {CONST_0_6215[31:16], CONST_0_6215[15:0]})[47:16];
                    if (cycle_count >= 8'd8) begin
                        next_state <= MULT4;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= MULT3;
                    end
                end

                MULT4: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Compute 11.37 * v^0.16
                    term4 <= $signed({v_pow_0_16[31:16], v_pow_0_16[15:0]} * 
                                   {CONST_11_37[31:16], CONST_11_37[15:0]})[47:16];
                    if (cycle_count >= 8'd8) begin
                        next_state <= ACCUM;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= MULT4;
                    end
                end

                ACCUM: begin
                    cycle_count <= cycle_count + 8'd1;
                    // Sum all terms: 13.12 + 0.6215*t - 11.37*v^0.16 + 0.3965*t*v^0.16
                    windchill_q16_16 <= CONST_13_12 + term3 - term4 + term2;
                    if (cycle_count >= 8'd8) begin
                        next_state <= ROUND;
                        cycle_count <= 8'd0;
                    end else begin
                        next_state <= ACCUM;
                    end
                end

                ROUND: begin
                    // Round to integer by adding 0.5 (0x00008000) and truncating
                    windchill_q16_16 <= windchill_q16_16 + 32'h00008000;
                    // Clamp result to prevent overflow
                    if (windchill_q16_16 > 32'h00013880) begin // 50.0 in Q16.16
                        result <= 16'd50;
                    end else if (windchill_q16_16 < 32'hFFD30000) begin // -80.0 in Q16.16
                        result <= 16'd(-80);
                    end else begin
                        result <= windchill_q16_16[31:16];
                    end
                    next_state <= DONE_STATE;
                end

                DONE_STATE: begin
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