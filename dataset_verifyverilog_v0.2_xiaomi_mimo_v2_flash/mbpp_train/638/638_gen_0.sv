module wind_chill(
    input clk,
    input rst_n,
    input start,
    input [15:0] v,
    input [15:0] t,
    output reg [15:0] result,
    output reg done
);

    // Constants in Q16.16
    parameter C1_13_12    = 24'h000D1F48;
    parameter C2_0_6215   = 24'h00009EB8;
    parameter C3_11_37    = 24'h000B5E64;
    parameter C4_0_3965   = 24'h0000659F;

    // State definition
    localparam IDLE  = 3'b000;
    localparam CALC1 = 3'b001;
    localparam CALC2 = 3'b010;
    localparam CALC3 = 3'b011;
    localparam CALC4 = 3'b100;
    localparam DONE  = 3'b101;

    reg [2:0] state, next_state;

    // Internal registers for pipeline
    reg [23:0] term1_mult;    // 0.6215 * t
    reg [23:0] v_pow;         // v^0.16 from LUT
    reg [47:0] term3_mult;    // 0.3965 * t * v_pow
    reg [47:0] term2_mult;    // 11.37 * v_pow
    reg signed [47:0] sum_res;// 13.12 + term1 - term2 + term3
    reg [15:0] rounded_res;   // Rounded integer result

    // Wires for combinational logic (LUT and multipliers)
    reg [23:0] v_pow_wire;
    reg [47:0] mult1_wire;
    reg [47:0] mult2_wire;
    reg [47:0] mult3_wire;
    reg signed [47:0] sum_wire;
    reg [15:0] round_wire;

    // LUT for v^0.16 (Q16.16 format)
    // Mapping v (0-120) to approximated values
    always @(*) begin
        case(v)
            // Values manually calculated/approximated for v^0.16 * 65536
            16'd0:   v_pow_wire = 24'h00000000; // 0.0
            16'd1:   v_pow_wire = 24'h00010000; // 1.0
            16'd2:   v_pow_wire = 24'h00012F6A; // 1.1852
            16'd3:   v_pow_wire = 24'h0001429C; // 1.2602
            16'd4:   v_pow_wire = 24'h00015000; // 1.3125
            16'd5:   v_pow_wire = 24'h00015A7B; // 1.3535
            16'd6:   v_pow_wire = 24'h00016350; // 1.3880
            16'd7:   v_pow_wire = 24'h00016B0F; // 1.4182
            16'd8:   v_pow_wire = 24'h00017200; // 1.4453
            16'd9:   v_pow_wire = 24'h0001784C; // 1.4699
            16'd10:  v_pow_wire = 24'h00017E13; // 1.4925
            16'd15:  v_pow_wire = 24'h0001999A; // 1.6000
            16'd20:  v_pow_wire = 24'h0001AE14; // 1.6799
            16'd25:  v_pow_wire = 24'h0001BC8B; // 1.7365
            16'd30:  v_pow_wire = 24'h0001C86B; // 1.7829
            16'd35:  v_pow_wire = 24'h0001D298; // 1.8226
            16'd40:  v_pow_wire = 24'h0001DB8B; // 1.8576
            16'd45:  v_pow_wire = 24'h0001E388; // 1.8889
            16'd50:  v_pow_wire = 24'h0001EAC6; // 1.9172
            16'd55:  v_pow_wire = 24'h0001F15E; // 1.9430
            16'd60:  v_pow_wire = 24'h0001F760; // 1.9663
            16'd65:  v_pow_wire = 24'h0001FCD7; // 1.9877
            16'd70:  v_pow_wire = 24'h000201D4; // 2.0071
            16'd75:  v_pow_wire = 24'h00020664; // 2.0249
            16'd80:  v_pow_wire = 24'h00020A91; // 2.0413
            16'd85:  v_pow_wire = 24'h00020E63; // 2.0566
            16'd90:  v_pow_wire = 24'h000211E5; // 2.0709
            16'd95:  v_pow_wire = 24'h00021520; // 2.0844
            16'd100: v_pow_wire = 24'h00021819; // 2.0971
            16'd105: v_pow_wire = 24'h00021AD8; // 2.1092
            16'd110: v_pow_wire = 24'h00021D62; // 2.1192
            16'd115: v_pow_wire = 24'h00021FBC; // 2.1240
            16'd120: v_pow_wire = 24'h000221EA; // 2.1325
            default: v_pow_wire = 24'h00000000;
        endcase
    end

    // Combinational logic for calculations
    // CALC1: 0.6215 * t (32-bit mult, result in Q32.16 -> shift by 16)
    // t is Q16.16, C2 is Q16.16. Product is Q32.32. We take upper 24 bits (Q16.16)
    // Actually result needs to be stored as Q16.16 compatible or larger for next stage.
    // Let's store mult results as Q32.16 (top 32 bits of 48-bit result)
    // 0.6215 * t result range: small, fits in 24 bits (Q8.16)
    always @(*) begin
        mult1_wire = C2_0_6215 * t; // 24*16 = 40 bits. 
        // C2 is 24bit val. t is 16bit. Product is 40 bits. 
        // We want 24 bits (Q16.16) for term1_mult.
        // mult1_wire[39:16] gives Q16.16 equivalent. 
        // term1_mult is 24 bits, so we take [39:16]
        term1_mult = mult1_wire[39:16];
    end

    // CALC2:
    // term2 = 11.37 * v_pow. C3 (24) * v_pow (24) -> 48 bits. Result Q32.16 (shift 16)
    // term3 = 0.3965 * t * v_pow. 
    // Mult step 1: (0.3965 * t) -> 48 bits. Take [39:16] -> 24 bits (Q16.16)
    // Mult step 2: (result) * v_pow -> 48 bits. Result Q32.16.
    always @(*) begin
        // Step 1 of term3: 0.3965 * t
        reg [47:0] temp_mult;
        temp_mult = C4_0_3965 * t;
        // term2 calculation
        mult2_wire = C3_11_37 * v_pow_wire;
        // term3 calculation (combining steps)
        mult3_wire = temp_mult[39:16] * v_pow_wire;
    end

    // CALC3: Summation
    // 13.12 + term1 - term2 + term3
    // term1, term2, term3 are Q32.16. 13.12 is Q16.16.
    // We need to align. Let's make 13.12 Q32.16 (shift left 16).
    // 13.12 << 16 = 0x0D1F480000 (Wait, 13.12 is 0x000D1F48. Shift 16 -> 0x0D1F480000, 36 bits)
    // Let's use 48 bits for summation.
    always @(*) begin
        reg signed [47:0] c1_ext;
        c1_ext = {8'b0, C1_13_12, 16'b0}; // Shifted to Q32.16
        sum_wire = c1_ext + {24'h0, term1_mult, 8'b0} - mult2_wire + mult3_wire;
        // Correction: term1_mult is 24 bits (Q16.16). We want Q32.16, so shift 16: {term1_mult, 16'b0}
        // Wait, mult1 gave [39:16]. That is Q16.16. So yes, {term1_mult, 16'b0}.
        // Actually, let's trace widths:
        // term1_mult: 24 bits. Stored as Q16.16? Or Q32.16?
        // If term1_mult is 24 bits Q16.16, it implies decimal is in lower 16.
        // Let's store term1_mult as 32 bits (Q16.16 padded) to simplify next stage? 
        // Or just keep as 24 and expand in calculation.
        // Let's refine types to avoid confusion.
        // term1_mult_reg (24b) -> {term1_mult_reg, 16'b0} for sum.
        // mult2_wire is 48b (Q32.16).
        // mult3_wire is 48b (Q32.16).
        
        // Re-eval sum_wire:
        // 13.12 (Q16.16) -> 0x0D1F480000 (36b) or simply mask to 48b.
        // term1 (Q16.16) -> 0xT0000000000 (shift 16)
        // term2 (Q32.16) -> 0xT0000000000 (no shift)
        // term3 (Q32.16) -> 0xT0000000000
        
        sum_wire = (C1_13_12 << 16) + (term1_mult << 16) - mult2_wire + mult3_wire;
    end

    // CALC4: Rounding
    // sum_wire is Q32.16. 
    // Integer part is in [47:16]. Fractional in [15:0].
    // Round: if [15] is 1, add 1 to integer part.
    always @(*) begin
        reg [31:0] int_part;
        reg        sign_bit;
        
        int_part = sum_wire[47:16];
        sign_bit = sum_wire[15];
        
        if (sign_bit) begin
            round_wire = int_part + 1;
        end else begin
            round_wire = int_part;
        end
    end

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next State Logic
    always @(*) begin
        case(state)
            IDLE:   if (start) next_state = CALC1;
                    else next_state = IDLE;
            CALC1:  next_state = CALC2;
            CALC2:  next_state = CALC3;
            CALC3:  next_state = CALC4;
            CALC4:  next_state = DONE;
            DONE:   if (start) next_state = CALC1; // Stay high until start goes low? Or restart on start?
                    else next_state = IDLE;
            default: next_state = IDLE;
        endcase
    end

    // Output Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
            result <= 16'b0;
            // Clear intermediate registers to avoid latches
            term1_mult <= 24'b0;
            v_pow <= 24'b0;
            term3_mult <= 48'b0;
            term2_mult <= 48'b0;
            sum_res <= 48'b0;
            rounded_res <= 16'b0;
        end else begin
            case(state)
                IDLE: begin
                    done <= 1'b0;
                end
                CALC1: begin
                    // LUT read happens combinationally on v input
                    v_pow <= v_pow_wire; 
                    // Multiply happens combinationally
                    term1_mult <= term1_mult; // logic assigned in comb block
                end
                CALC2: begin
                    // term2 and term3 multiplication
                    term2_mult <= mult2_wire;
                    term3_mult <= mult3_wire;
                end
                CALC3: begin
                    // Summation
                    sum_res <= sum_wire;
                end
                CALC4: begin
                    // Rounding and truncation to 16 bits
                    // Check bounds? Result is integer. 
                    rounded_res <= round_wire;
                end
                DONE: begin
                    done <= 1'b1;
                    result <= rounded_res;
                end
            endcase
        end
    end

endmodule
