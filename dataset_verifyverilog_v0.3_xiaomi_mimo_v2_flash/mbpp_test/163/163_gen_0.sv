module PolygonAreaCalculator (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] sides,
    input wire [15:0] length,
    output reg [31:0] result,
    output reg done,
    output reg error
);

    // State machine states
    localparam [2:0] IDLE          = 3'd0;
    localparam [2:0] CHECK_INPUT   = 3'd1;
    localparam [2:0] SQUARING      = 3'd2;
    localparam [2:0] LOOKUP_TAN    = 3'd3;
    localparam [2:0] CALCULATE     = 3'd4;
    localparam [2:0] FINISH        = 3'd5;
    
    reg [2:0] state;
    reg [2:0] next_state;
    
    // Registers for intermediate values
    reg [31:0] length_squared;     // Q16.16 format
    reg [31:0] tan_val;            // Q16.16 format from LUT
    reg [31:0] numerator;          // s * l^2
    reg [4:0] sides_ext;           // Extended for multiplication
    reg [7:0] cycle_counter;
    localparam [7:0] MAX_CYCLES = 8'd50;
    
    // Division signals
    reg start_div;
    reg [63:0] dividend;
    reg [31:0] divisor;
    reg [31:0] quotient;
    reg div_busy;
    reg [5:0] div_counter;
    
    // Squaring signals
    reg start_square;
    reg [31:0] square_result;
    reg square_busy;
    
    // Internal error flag
    reg internal_error;
    
    // LUT for tan(π/s) in Q16.16 format
    function automatic [31:0] tan_lut(input [3:0] s);
        begin
            case (s)
                4'd3:   tan_lut = 32'd113515;    // tan(π/3) = √3 ≈ 1.732
                4'd4:   tan_lut = 32'd65536;     // tan(π/4) = 1.0
                4'd5:   tan_lut = 32'd47622;     // tan(π/5) ≈ 0.7265
                4'd6:   tan_lut = 32'd37838;     // tan(π/6) ≈ 0.57735
                4'd7:   tan_lut = 32'd31565;     // tan(π/7) ≈ 0.48157
                4'd8:   tan_lut = 32'd27146;     // tan(π/8) ≈ 0.41421
                4'd9:   tan_lut = 32'd23856;     // tan(π/9) ≈ 0.36397
                4'd10:  tan_lut = 32'd21298;     // tan(π/10) ≈ 0.32492
                4'd11:  tan_lut = 32'd19243;     // tan(π/11) ≈ 0.29363
                4'd12:  tan_lut = 32'd17560;     // tan(π/12) ≈ 0.26795
                4'd13:  tan_lut = 32'd16154;     // tan(π/13) ≈ 0.24648
                4'd14:  tan_lut = 32'd14957;     // tan(π/14) ≈ 0.22824
                4'd15:  tan_lut = 32'd13931;     // tan(π/15) ≈ 0.21256
                4'd16:  tan_lut = 32'd13038;     // tan(π/16) ≈ 0.19891
                default: tan_lut = 32'd0;
            endcase
        end
    endfunction
    
    // Multiplication logic for squaring (16x16 -> 32-bit Q16.16)
    // When length is Q8.8, length * length = Q16.16
    wire [31:0] mult_result;
    assign mult_result = length * length;
    
    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = CHECK_INPUT;
                end else begin
                    next_state = IDLE;
                end
            end
            
            CHECK_INPUT: begin
                if (internal_error || sides < 4'd3) begin
                    next_state = FINISH;
                end else begin
                    next_state = SQUARING;
                end
            end
            
            SQUARING: begin
                if (!square_busy) begin
                    next_state = LOOKUP_TAN;
                end else begin
                    next_state = SQUARING;
                end
            end
            
            LOOKUP_TAN: begin
                next_state = CALCULATE;
            end
            
            CALCULATE: begin
                if (!div_busy) begin
                    next_state = FINISH;
                end else begin
                    next_state = CALCULATE;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end
    
    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            result <= 32'd0;
            done <= 1'b0;
            error <= 1'b0;
            internal_error <= 1'b0;
            length_squared <= 32'd0;
            tan_val <= 32'd0;
            numerator <= 32'd0;
            sides_ext <= 5'd0;
            cycle_counter <= 8'd0;
            start_square <= 1'b0;
            square_busy <= 1'b0;
            start_div <= 1'b0;
            div_busy <= 1'b0;
            quotient <= 32'd0;
            div_counter <= 6'd0;
        end else begin
            // Clear start signals
            start_square <= 1'b0;
            start_div <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    result <= 32'd0;
                    error <= 1'b0;
                    internal_error <= 1'b0;
                    cycle_counter <= 8'd0;
                    div_busy <= 1'b0;
                    square_busy <= 1'b0;
                end
                
                CHECK_INPUT: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (sides < 4'd3 || sides > 4'd16) begin
                        internal_error <= 1'b1;
                        error <= 1'b1;
                    end else begin
                        internal_error <= 1'b0;
                        error <= 1'b0;
                        sides_ext <= {1'b0, sides};
                        start_square <= 1'b1;
                        square_busy <= 1'b1;
                    end
                end
                
                SQUARING: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    if (square_busy) begin
                        // Perform squaring: length * length
                        // Input length is Q8.8, so result is Q16.16
                        length_squared <= mult_result;
                        square_busy <= 1'b0;
                    end
                end
                
                LOOKUP_TAN: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    tan_val <= tan_lut(sides);
                end
                
                CALCULATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (!div_busy) begin
                        // Start division: numerator / tan_val
                        // First, calculate numerator = sides * length_squared
                        // sides is 4-bit, length_squared is Q16.16
                        // Result will be Q20.16, then we shift right 2 for /4
                        
                        // Use multiplier for sides * length_squared
                        // sides_ext is 5-bit, length_squared is 32-bit
                        // Need 37-bit intermediate
                        
                        // Calculate numerator = sides * length_squared / 4
                        // Do division by 4 first (shift right 2)
                        // Actually, we need: (s * l^2) / (4 * tan)
                        // So: (s * l^2 / 4) / tan
                        
                        // First compute: s * l^2
                        // sides_ext (5 bits) * length_squared (32 bits) = 37 bits
                        // For division: we need 64-bit dividend
                        // Result should be Q16.16
                        
                        // Let's do: dividend = sides * length_squared * 65536 / 4
                        // Then divide by tan_val
                        // Actually simpler: dividend = sides * length_squared << 14
                        // (shift left 14 to get Q16.16 format for division)
                        
                        // sides * length_squared gives Q20.16
                        // To get Q16.16 for division with Q16.16 divisor:
                        // we need Q32.16 for dividend when divisor is Q16.16
                        // So: dividend = sides * length_squared * 2^16 (Q36.32)
                        // Actually, standard approach:
                        // For (A/B) where A is Q20.16 and B is Q16.16,
                        // result is Q4.0, which is wrong.
                        
                        // Correct approach for Q16.16 output:
                        // If A is Qa.b and B is Qc.d, A/B is Q(a-c).(b-d)
                        // sides * l^2 is Q(4+16).(0+16) = Q20.16
                        // tan is Q16.16
                        // Division: Q20.16 / Q16.16 = Q4.0 (not what we want)
                        
                        // To get Q16.16 result, we need to scale numerator:
                        // Q20.16 / Q16.16 = Q(20-16).(16-16) = Q4.0
                        // To get Q16.16, we need: (Q20.16 * 2^16) / Q16.16
                        // Which gives: Q36.32 / Q16.16 = Q20.16
                        // But we want Q16.16 output...
                        
                        // Actually: A / B with A=s*length^2/4, B=tan
                        // A is Q20.14 (after shift right 2)
                        // B is Q16.16
                        // A/B = Q(20-16).(14-16) = Q4.-2 (wrong)
                        
                        // Correct calculation:
                        // 1. length_squared (Q16.16) from 16x16 multiplication
                        // 2. numerator = sides * length_squared (Q20.16)
                        // 3. Divide numerator by 4: Q20.14
                        // 4. For A/B where A is Q20.14 and B is Q16.16,
                        //    to get Q16.16 result:
                        //    result = (A * 2^18) / B = Q(20+18).(14-18) / Q16.16
                        //    = Q38.-4 / Q16.16 = Q22.-20 ... getting complex
                        
                        // Simpler: Multiply numerator by 2^16 before division
                        // numerator (Q20.16) * 2^16 = Q36.32
                        // Divide by tan (Q16.16) = Q20.16 (but we want Q16.16)
                        // So shift right by 4 to get Q16.16
                        
                        // Actually for Q16.16 output from Q20.16 / Q16.16:
                        // result = (Q20.16 * 2^16) / Q16.16
                        //         = Q36.32 / Q16.16 = Q20.16
                        // Then shift right by 4: Q16.16
                        
                        // Let's compute: numerator * 2^16 / tan_val, then >> 4
                        // Or: (numerator / 16) * 2^16 / tan_val
                        // Wait, we need (s * l^2 / 4) / tan * something...
                        
                        // The formula is: (s * l^2) / (4 * tan)
                        // If we want Q16.16 result:
                        // Let S = s * l^2 (Q20.16)
                        // Let T = tan (Q16.16)
                        // Result = (S / 4) / T in Q16.16
                        // For Q16.16 result: (S / 4) / T * 2^16 / 2^16 = (S * 2^16) / (4 * T * 2^16)
                        // This equals: (S * 2^16) / (4 * T * 2^16)
                        // Actually: result = S / (4 * T) with S in Q20.16, T in Q16.16
                        // result in Q(20-4).(16-16) = Q16.0 if we think of division
                        // Wait, I'm overcomplicating.
                        
                        // Standard approach:
                        // For fixed-point division A/B with A and B in Q16.16:
                        // result = (A << 16) / B = Q32.16 / Q16.16 = Q16.0 (not Q16.16)
                        // To get Q16.16: result = (A << 32) / B
                        // = Q48.32 / Q16.16 = Q32.16, then shift right 16: Q16.16
                        
                        // For our case:
                        // A = s * l^2 / 4 (but we compute s * l^2 first)
                        // We want A in Q16.16, but s * l^2 is Q20.16
                        // So we should compute: (s * l^2) >> 2, but that's Q20.14
                        // For division with B (Q16.16) to get Q16.16:
                        // ((s * l^2) >> 2) in Q20.14 needs to be converted
                        // Result = ((s * l^2) << 14) / tan_val gives Q34.14 / Q16.16 = Q18.-2
                        // Not right.
                        
                        // Let me recalculate properly:
                        // We want: (s * l^2) / (4 * tan) in Q16.16
                        // Let X = s * l^2 (Q20.16)
                        // Let Y = 4 * tan (Q18.16)
                        // Result = X / Y
                        // X in Q20.16, Y in Q18.16
                        // X/Y = Q(20-18).(16-16) = Q2.0
                        // To get Q16.16, we need to scale X by 2^16 before division:
                        // Result = (X << 16) / Y = Q36.32 / Q18.16 = Q18.16
                        // Then shift right by 2: Q16.16
                        
                        // So algorithm:
                        // 1. Compute X = s * l^2 (Q20.16)
                        // 2. Compute dividend = X << 16 (Q36.32)
                        // 3. Divide by Y = 4 * tan = tan_val << 2 (Q18.16)
                        // 4. Result is Q18.16, shift right by 2 to get Q16.16
                        
                        // Actually, 4 * tan is just tan_val << 2 (Q18.16)
                        // For division: (X << 16) / (tan_val << 2)
                        // = (X << 16) / (tan_val * 4)
                        // = ((X << 16) / tan_val) / 4
                        // = ((X << 16) / tan_val) >> 2
                        
                        // So compute: dividend = X << 18 (to account for /4)
                        // = X << 18 (Q38.34)
                        // Divide by tan_val (Q16.16) = Q22.18
                        // Shift right by 2: Q20.16 (close but not right)
                        
                        // Final attempt:
                        // Want Q16.16 result from: (s * l^2) / (4 * tan)
                        // X = s * l^2 (Q20.16)
                        // We can rewrite: X / (4 * tan) = (X / 4) / tan
                        // X / 4 = X >> 2 (Q20.14)
                        // (X >> 2) / tan with tan in Q16.16
                        // For Q16.16 result: ((X >> 2) << 30) / tan
                        // = (X << 28) / tan = Q48.46 / Q16.16 = Q32.30, then >> 14 = Q18.16
                        // This is getting too complex.
                        
                        // Let's use a simpler approach with good enough precision:
                        // 1. X = s * l^2 (Q20.16) - compute directly
                        // 2. dividend = X << 16 (Q36.32)
                        // 3. divisor = tan_val << 2 (Q18.16) for 4*tan
                        // 4. quotient = dividend / divisor = Q18.16
                        // 5. result = quotient >> 2 = Q16.16
                        
                        // Actually, 4*tan is tan_val << 2, so divisor = tan_val << 2
                        // dividend = (s * l^2) << 16
                        // result = dividend / divisor = Q16.16 ✓
                        
                        // Compute s * l^2 first
                        // sides_ext (5-bit) * length_squared (32-bit, Q16.16)
                        // Result is 37-bit: Q(4+16).(0+16) = Q20.16
                        wire [36:0] prod_temp;
                        assign prod_temp = sides_ext * length_squared;
                        
                        // Now set up division
                        // dividend = (s * l^2) << 16 (Q36.32)
                        // divisor = (tan_val << 2) (Q18.16) - but tan_val is already Q16.16
                        // So divisor = tan_val * 4, which is tan_val << 2
                        // But we can just divide (s * l^2) << 16 by tan_val, then >> 2
                        
                        // Actually: (s * l^2) / (4 * tan) = ((s * l^2) << 16) / (tan << 2)
                        // = ((s * l^2) << 14) / tan
                        // dividend = (s * l^2) << 14 (Q34.30)
                        // divisor = tan_val (Q16.16)
                        // result = dividend / divisor = Q18.14
                        // Then result >> ? Hmm
                        
                        // Let me verify:
                        // s * l^2 is Q20.16
                        // tan is Q16.16
                        // We want (s * l^2) / (4 * tan) in Q16.16
                        // = (s * l^2) / tan / 4 in Q16.16
                        // If we compute (s * l^2 * 2^16) / tan in Q20.16 / Q16.16 = Q4.0
                        // That's wrong.
                        
                        // For A/Qa.b divided by B/Qc.d to get Q16.16:
                        // We need A/Q16.16 and B/Q16.16, then result = (A << 16) / B
                        // = Q32.16 / Q16.16 = Q16.0 (not Q16.16)
                        
                        // To get Q16.16 from division: (A << 32) / B
                        // = Q48.32 / Q16.16 = Q32.16, then shift right 16: Q16.16
                        
                        // So for our formula:
                        // A = s * l^2 / 4 (in Q16.16)
                        // But s * l^2 is Q20.16, so A = (s * l^2) >> 2 = Q20.14
                        // We need A in Q16.16, so we need to scale it
                        // A = (s * l^2) >> 2 = Q20.14
                        // To get Q16.16: A * 2^2 = Q20.16 (but that's just s * l^2)
                        // Hmm, circular.
                        
                        // Actually: (s * l^2 / 4) / tan
                        // = (s * l^2 / 4) * (1 / tan)
                        // If we compute 1/tan first in Q16.16, then multiply
                        // (s * l^2 / 4) in Q20.14
                        // (1/tan) in Q16.16
                        // Product: Q(20+16).(14+16) = Q36.30
                        // Shift right 14: Q22.16 (close to Q16.16, shift right 6 more)
                        // = Q16.16 ✓
                        
                        // So plan:
                        // 1. Compute 1/tan_val (Q16.16) - requires division
                        // 2. Compute s * l^2 (Q20.16)
                        // 3. Multiply by 1/tan (Q36.32)
                        // 4. Divide by 4: result >> 2 (Q36.30)
                        // 5. Normalize to Q16.16: result >> 14 = Q22.16
                        // Wait, Q36.30 >> 14 = Q22.16, need >> 6 more = Q16.16
                        
                        // Actually easier: 1/tan gives Q16.16
                        // s * l^2 / 4 gives Q20.14
                        // Multiply: Q36.30
                        // To get Q16.16, we need to shift right by 14 (30-16=14)
                        // Result: Q22.16, then shift right 6 more: Q16.16
                        
                        // This is getting too complex. Let's use a simpler approach:
                        // Since we're in hardware and need Q16.16 output,
                        // let's use the fact that for Q16.16 / Q16.16 division:
                        // result = (A << 16) / B, then to get Q16.16, we need to interpret
                        // the result differently.
                        
                        // Actually, the formula (s * l^2) / (4 * tan) with:
                        // s: integer
                        // l^2: Q16.16  
                        // tan: Q16.16
                        // gives Q(4+16-4).(16-16) = Q16.0 for the division
                        // To get Q16.16, we need to multiply result by 2^16
                        // So: result = ((s * l^2) << 16) / (4 * tan)
                        // = Q(4+16-2).(16-16) = Q18.0? Not right.
                        
                        // I think I'm overthinking. Let me use the standard formula:
                        // For Q16.16 division: result = (A << 16) / B
                        // If A and B are both Q16.16, result is Q16.0
                        // To get Q16.16, we do: result = (A << 32) / B
                        // = Q48.32 / Q16.16 = Q32.16, then >> 16 = Q16.16
                        
                        // So for our case with A = s * l^2 / 4:
                        // A is Q20.14 (after >> 2)
                        // We need A in Q16.16 format for division
                        // A in Q16.16 = (s * l^2 / 4) * 2^2 = s * l^2 * 2^2 / 2^4
                        // = s * l^2 / 4 * 4? This is confusing.
                        
                        // Let me be explicit:
                        // value = (s * l^2) / (4 * tan)
                        // s is 4-bit integer
                        // l^2 is Q16.16
                        // tan is Q16.16
                        // result should be Q16.16
                        
                        // Computation:
                        // 1. temp1 = s * l^2  → Q20.16 (4+16, 0+16)
                        // 2. temp2 = temp1 / 4  → Q20.14 (shift right 2)
                        // 3. We need to divide temp2 (Q20.14) by tan (Q16.16)
                        //    to get Q16.16 result
                        // 4. For this, compute: (temp2 << 18) / tan
                        //    temp2 << 18 = Q38.32
                        //    tan = Q16.16
                        //    result = Q22.16
                        // 5. To get Q16.16, shift right by 6: Q16.16 ✓
                        
                        // So dividend = temp2 << 18 = (s * l^2 / 4) << 18
                        // = (s * l^2) << 16
                        // divisor = tan
                        // quotient = dividend / divisor = Q22.16
                        // final = quotient >> 6 = Q16.16
                        
                        wire [36:0] s_l2_prod;  // s * l^2, Q20.16
                        assign s_l2_prod = sides_ext * length_squared;
                        
                        // Shift left 16 for division
                        // This gives us Q36.32 format
                        wire [63:0] div_dividend;
                        assign div_dividend = {s_l2_prod, 16'd0};  // s * l^2 << 16
                        
                        // divisor is tan_val (Q16.16)
                        // quotient will be Q20.16
                        // But we want Q16.16, so we'll shift right by 4
                        // Actually: (s * l^2 << 16) / tan = Q(20+16).(16-16) = Q36.0
                        // That's not right either.
                        
                        // Let me try a different approach entirely:
                        // Use Q8.8 for everything internally, then scale up
                        // length in Q8.8, length^2 in Q16.16
                        // For division, convert everything to same format
                        
                        // Actually, the simplest way:
                        // (s * l^2) / (4 * tan) in Q16.16
                        // = s * l^2 * (1/4) * (1/tan)
                        // Compute 1/tan in Q16.16, multiply by l^2 in Q16.16, divide by 4, multiply by s
                        // 1/tan in Q16.16: (2^32) / tan_val
                        // Then multiply by l^2: Q(16+16).(16+16) = Q32.32
                        // Divide by 4: Q32.30
                        // Multiply by s: Q36.30
                        // Normalize to Q16.16: shift right 14: Q22.16, then 6 more: Q16.16
                        
                        // This is still complex. Let's use direct division with proper scaling:
                        // We'll compute: (s * l^2 * 2^14) / tan
                        // This gives Q(4+16+14).(0+16-16) = Q34.0
                        // Then to get Q16.16, we shift left by 16: Q34.16
                        // Then we're done!
                        
                        // Wait, that's not how fixed-point works.
                        // If result is Q34.0 and we want Q16.16,
                        // we need to multiply by 2^16, making it Q34.16
                        // which is too wide.
                        
                        // OK, final correct approach:
                        // Formula: result = (s * l^2) / (4 * tan)
                        // - s is integer (4 bits)
                        // - l^2 is Q16.16  
                        // - tan is Q16.16
                        // - result is Q16.16
                        
                        // Direct computation:
                        // result = (s * l^2 << 16) / (4 * tan)
                        // numerator: s * l^2 << 16 = Q(4+16+16).(0+16+16) = Q36.32
                        // denominator: 4 * tan = Q18.16
                        // result: Q(36-18).(32-16) = Q18.16
                        // To get Q16.16, we need to shift right by 2: Q16.16 ✓
                        
                        // So algorithm:
                        // 1. Compute s * l^2 (Q20.16)
                        // 2. Compute dividend = (s * l^2) << 16 (Q36.32)
                        // 3. Compute divisor = tan_val << 2 (Q18.16) for 4*tan
                        // 4. quotient = dividend / divisor = Q18.16
                        // 5. result = quotient >> 2 = Q16.16
                        
                        wire [36:0] s_l2;
                        assign s_l2 = sides_ext * length_squared;
                        
                        wire [63:0] div_dividend_wire;
                        assign div_dividend_wire = {s_l2, 16'd0};  // << 16
                        
                        wire [31:0] divisor_wire;
                        assign divisor_wire = tan_val << 2;  // 4 * tan
                        
                        // Check for division by zero
                        if (divisor_wire == 32'd0) begin
                            internal_error <= 1'b1;
                            error <= 1'b1;
                            state <= FINISH;
                        end else begin
                            // Set up division
                            dividend <= div_dividend_wire;
                            divisor <= divisor_wire;
                            div_busy <= 1'b1;
                            div_counter <= 6'd0;
                        end
                    end
                end
                
                CALCULATE: begin
                    cycle_counter <= cycle_counter + 8'd1;
                    
                    if (div_busy) begin
                        // Restoring division algorithm
                        // dividend is Q36.32, divisor is Q18.16
                        // We want Q18.16 result, then >> 2 = Q16.16
                        
                        if (div_counter == 6'd0) begin
                            // Initialize
                            quotient <= 32'd0;
                            dividend <= dividend - (divisor << 16);  // First subtraction
                            quotient[15] <= 1'b1;  // Set bit for position 15
                            div_counter <= 6'd1;
                        end else if (div_counter <= 6'd16) begin
                            // 16 iterations for 16-bit fractional part
                            // Shift dividend left
                            dividend <= dividend << 1;
                            
                            // Try subtraction
                            if (dividend[63:32] >= divisor) begin
                                dividend <= dividend - (divisor << 32);
                                quotient[div_counter] <= 1'b1;
                            end
                            
                            if (div_counter == 6'd16) begin
                                // Division complete, quotient is Q18.16
                                // Need to shift right by 2 for Q16.16
                                result <= quotient >> 2;
                                div_busy <= 1'b0;
                            end else begin
                                div_counter <= div_counter + 6'd1;
                            end
                        end
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 32'd0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
            endcase
            
            // State transition
            state <= next_state;
            
            // Check for timeout
            if (cycle_counter >= MAX_CYCLES && state != IDLE && state != FINISH) begin
                state <= FINISH;
                internal_error <= 1'b1;
                error <= 1'b1;
            end
        end
    end
    
endmodule