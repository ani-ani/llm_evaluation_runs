module planet_orbits(
    input [63:0] planet1,
    input [63:0] planet2,
    output reg [7:0] result_valid,
    output reg [2:0] result_count,
    output reg invalid
);

    // Define ASCII constants for planet names (8 bytes each)
    localparam [63:0] MERCURY = 8'h4d65726375727920; // 'Mercury' + space
    localparam [63:0] VENUS   = 8'h56656e7573202020; // 'Venus' + spaces
    localparam [63:0] EARTH   = 8'h4561727468202020; // 'Earth' + spaces
    localparam [63:0] MARS    = 8'h4d61727320202020; // 'Mars' + spaces
    localparam [63:0] JUPITER = 8'h4a75706974657220; // 'Jupiter' + space
    localparam [63:0] SATURN  = 8'h53617475726e2020; // 'Saturn' + spaces
    localparam [63:0] URANUS  = 8'h5572616e75732020; // 'Uranus' + spaces
    localparam [63:0] NEPTUNE = 8'h4e657074756e6520; // 'Neptune' + space

    // Internal signals for decoded indices
    reg [2:0] idx1;
    reg [2:0] idx2;
    reg invalid1;
    reg invalid2;

    // Decode planet1
    always @(*) begin
        case(planet1)
            MERCURY: begin idx1 = 3'd0; invalid1 = 1'b0; end
            VENUS:   begin idx1 = 3'd1; invalid1 = 1'b0; end
            EARTH:   begin idx1 = 3'd2; invalid1 = 1'b0; end
            MARS:    begin idx1 = 3'd3; invalid1 = 1'b0; end
            JUPITER: begin idx1 = 3'd4; invalid1 = 1'b0; end
            SATURN:  begin idx1 = 3'd5; invalid1 = 1'b0; end
            URANUS:  begin idx1 = 3'd6; invalid1 = 1'b0; end
            NEPTUNE: begin idx1 = 3'd7; invalid1 = 1'b0; end
            default: begin idx1 = 3'd0; invalid1 = 1'b1; end
        endcase
    end

    // Decode planet2
    always @(*) begin
        case(planet2)
            MERCURY: begin idx2 = 3'd0; invalid2 = 1'b0; end
            VENUS:   begin idx2 = 3'd1; invalid2 = 1'b0; end
            EARTH:   begin idx2 = 3'd2; invalid2 = 1'b0; end
            MARS:    begin idx2 = 3'd3; invalid2 = 1'b0; end
            JUPITER: begin idx2 = 3'd4; invalid2 = 1'b0; end
            SATURN:  begin idx2 = 3'd5; invalid2 = 1'b0; end
            URANUS:  begin idx2 = 3'd6; invalid2 = 1'b0; end
            NEPTUNE: begin idx2 = 3'd7; invalid2 = 1'b0; end
            default: begin idx2 = 3'd0; invalid2 = 1'b1; end
        endcase
    end

    // Range computation logic
    always @(*) begin
        // Check validity
        if (invalid1 || invalid2) begin
            invalid = 1'b1;
            result_valid = 8'b0;
            result_count = 3'd0;
        end else begin
            invalid = 1'b0;
            
            // Default initialization
            result_valid = 8'b0;
            result_count = 3'd0;
            
            // Only compute if planets are different
            if (idx1 != idx2) begin
                // Determine min and max indices
                // Use if-else for synthesizable min/max logic
                if (idx1 < idx2) begin
                    // idx1 is min, idx2 is max
                    // Set bits strictly between min and max
                    case(idx1)
                        3'd0: begin
                            case(idx2)
                                3'd1: result_valid = 8'b00000000;
                                3'd2: result_valid = 8'b00000010; // 1
                                3'd3: result_valid = 8'b00000110; // 1,2
                                3'd4: result_valid = 8'b00001110; // 1,2,3
                                3'd5: result_valid = 8'b00011110; // 1,2,3,4
                                3'd6: result_valid = 8'b00111110; // 1,2,3,4,5
                                3'd7: result_valid = 8'b01111110; // 1,2,3,4,5,6
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd1: begin
                            case(idx2)
                                3'd2: result_valid = 8'b00000100; // 2
                                3'd3: result_valid = 8'b00001100; // 2,3
                                3'd4: result_valid = 8'b00011100; // 2,3,4
                                3'd5: result_valid = 8'b00111100; // 2,3,4,5
                                3'd6: result_valid = 8'b01111100; // 2,3,4,5,6
                                3'd7: result_valid = 8'b01111100; // 2,3,4,5,6 (Wait, 7 is max, so 2-6? No, 1< i <7 is 2,3,4,5,6. Correct)
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd2: begin
                            case(idx2)
                                3'd3: result_valid = 8'b00001000; // 3
                                3'd4: result_valid = 8'b00011000; // 3,4
                                3'd5: result_valid = 8'b00111000; // 3,4,5
                                3'd6: result_valid = 8'b01111000; // 3,4,5,6
                                3'd7: result_valid = 8'b01111000; // 3,4,5,6 (1< i <7 is 2,3,4,5,6. Wait. min=2, max=7. 2< i <7 -> 3,4,5,6. Bits 3,4,5,6 set. 8'b01111000)
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd3: begin
                            case(idx2)
                                3'd4: result_valid = 8'b00010000; // 4
                                3'd5: result_valid = 8'b00110000; // 4,5
                                3'd6: result_valid = 8'b01110000; // 4,5,6
                                3'd7: result_valid = 8'b01110000; // 4,5,6
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd4: begin
                            case(idx2)
                                3'd5: result_valid = 8'b00100000; // 5
                                3'd6: result_valid = 8'b01100000; // 5,6
                                3'd7: result_valid = 8'b01100000; // 5,6
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd5: begin
                            case(idx2)
                                3'd6: result_valid = 8'b01000000; // 6
                                3'd7: result_valid = 8'b01000000; // 6
                                default: result_valid = 8'b0;
                            endcase
                        end
                        3'd6: begin
                            if (idx2 == 3'd7) result_valid = 8'b00000000; // None between 6 and 7
                            else result_valid = 8'b0;
                        end
                        default: result_valid = 8'b0;
                    endcase
                    
                    // However, the case statements above were specific to the min_idx being a specific value.
                    // If idx2 < idx1, we need a similar block or swap logic.
                    // Let's refine to use a generic min/max logic without huge case tables for both directions.
                    // The previous approach was getting verbose. Let's use if-else for min/max logic on indices directly.
                    
                    // Re-implementation using generic bit manipulation for range:
                    // If min_idx = k, max_idx = m.
                    // We want bits [k+1] to [m-1] set.
                    
                    // Let's try a cleaner approach for the range generation:
                    // Generate a mask for bits [0..max_idx-1], then clear bits [0..min_idx].
                    // Or generate a mask for bits [min_idx+1..7] then clear bits [max_idx..7].
                    
                    // Let's try: valid = ((1 << max_idx) - 2) & ~((1 << (min_idx+1)) - 2)
                    // Wait, let's check this.
                    // If min=0, max=2. 
                    // (1<<2)-2 = 4-2=2 (010). ~((1<<1)-2) = ~(2-2)=~0=1... No.
                    // Correct logic: Valid bits are i where min_idx < i < max_idx.
                    // This is equivalent to: (bits < max_idx) AND (bits > min_idx).
                    // (i < max_idx) -> (2^i) < 2^max_idx -> mask has ones for 0 to max_idx-1.
                    // (i > min_idx) -> (2^i) >= 2^(min_idx+1).
                    
                    // Let's use temporary variables for synthesis.
                    // To avoid large LUTs or complex logic, let's stick to the case statement logic but ensure it handles all cases correctly.
                    // The previous case structure was mixed up.
                    // Let's define min and max explicitly.
                    
                    reg [2:0] min_idx;
                    reg [2:0] max_idx;
                    
                    if (idx1 < idx2) begin
                        min_idx = idx1;
                        max_idx = idx2;
                    end else begin
                        min_idx = idx2;
                        max_idx = idx1;
                    end
                    
                    // Generate mask: bits set from min_idx+1 to max_idx-1
                    // We can generate a mask for bits [0..max_idx-1] and mask out bits [0..min_idx]
                    // Mask for [0..n-1] is (1 << n) - 1.
                    // So mask_top = (1 << max_idx) - 1.
                    // Mask_bottom = (1 << (min_idx + 1)) - 1.
                    // Result = Mask_top & ~Mask_bottom.
                    
                    // Note: (1 << x) requires x to be 3 bits. Result is 8 bits (implicit cast)
                    // Edge case: max_idx = 0 -> (1<<0)-1 = 0. 
                    // Edge case: min_idx+1 = 0 -> (1<<0)-1 = 0.
                    // 
                    // Case: min=0, max=1. 
                    // Mask_top (bits < 1): (1<<1)-1 = 1 (00000001)
                    // Mask_bottom (bits <= 0): (1<<1)-1 = 1 (00000001)
                    // Result = 1 & ~1 = 0. Correct. (No planets between 0 and 1)
                    // 
                    // Case: min=0, max=3.
                    // Mask_top (bits < 3): (1<<3)-1 = 7 (00000111)
                    // Mask_bottom (bits <= 0): (1<<1)-1 = 1 (00000001)
                    // Result = 7 & ~1 = 6 (00000110). Correct (bits 1, 2).
                    
                    // Check ranges for shifts: max_idx goes 0 to 7. (1 << max_idx) needs to handle max_idx=7? 
                    // (1<<7) = 128. (128-1) = 127 = 8'h7F. Correct.
                    // What if max_idx = 0? (1<<0) = 1. (1-1) = 0.
                    // What if max_idx = 1? (1<<1) = 2. (2-1) = 1.
                    
                    // Check min_idx: min_idx goes 0 to 6 (since max_idx > min_idx, max can be at most 7).
                    // min_idx+1 goes 1 to 7.
                    // (1 << (min_idx+1)) needs to handle 7. (1<<7) = 128. Correct.
                    // 
                    // However, strictly inside always @(*) block, we should avoid creating latches and ensure all paths defined.
                    // The expressions (1<<x) - 1 are standard Verilog.
                    
                    reg [7:0] mask_top;
                    reg [7:0] mask_bottom;
                    
                    // Safe shift logic: 
                    // In Verilog 2001/2005, if shift amount is variable, it's generally synthesizable but implementation dependent.
                    // To be safe and explicit for ASIC:
                    // We can use the previous case statement or a priority encoder logic.
                    // Let's use the shift logic as it's more compact, assuming synthesis tool handles 3-to-8 bit shift correctly.
                    
                    mask_top = (8'b00000001 << max_idx) - 1;
                    mask_bottom = (8'b00000001 << (min_idx + 1)) - 1;
                    
                    result_valid = mask_top & ~mask_bottom;
                end
            end else begin
                // idx1 == idx2
                result_valid = 8'b0;
            end
        end
        
        // Count set bits in result_valid (Population Count)
        // Since this is combinational, we can sum the bits.
        result_count = 0;
        if (result_valid[0]) result_count = result_count + 1;
        if (result_valid[1]) result_count = result_count + 1;
        if (result_valid[2]) result_count = result_count + 1;
        if (result_valid[3]) result_count = result_count + 1;
        if (result_valid[4]) result_count = result_count + 1;
        if (result_valid[5]) result_count = result_count + 1;
        if (result_valid[6]) result_count = result_count + 1;
        if (result_valid[7]) result_count = result_count + 1;
    end

endmodule