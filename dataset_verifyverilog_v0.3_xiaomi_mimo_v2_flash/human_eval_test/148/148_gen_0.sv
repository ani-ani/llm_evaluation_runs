module planet_filter(
    // Planet1 inputs (8 characters)
    input [7:0] planet1_char0,
    input [7:0] planet1_char1,
    input [7:0] planet1_char2,
    input [7:0] planet1_char3,
    input [7:0] planet1_char4,
    input [7:0] planet1_char5,
    input [7:0] planet1_char6,
    input [7:0] planet1_char7,
    
    // Planet2 inputs (8 characters)
    input [7:0] planet2_char0,
    input [7:0] planet2_char1,
    input [7:0] planet2_char2,
    input [7:0] planet2_char3,
    input [7:0] planet2_char4,
    input [7:0] planet2_char5,
    input [7:0] planet2_char6,
    input [7:0] planet2_char7,
    
    // Output: bitmask of planets between
    output reg [7:0] result
);

    // Local parameters for planet indices
    localparam [2:0] MERCURY = 3'd0;
    localparam [2:0] VENUS   = 3'd1;
    localparam [2:0] EARTH   = 3'd2;
    localparam [2:0] MARS    = 3'd3;
    localparam [2:0] JUPITER = 3'd4;
    localparam [2:0] SATURN  = 3'd5;
    localparam [2:0] URANUS  = 3'd6;
    localparam [2:0] NEPTUNE = 3'd7;
    
    // Combinational logic for decoding
    reg [2:0] index1;
    reg [2:0] index2;
    reg valid1;
    reg valid2;
    reg [2:0] min_index;
    reg [2:0] max_index;
    reg [7:0] mask;
    integer i;
    
    // Helper wire to check string equality
    wire [63:0] planet1_packed;
    wire [63:0] planet2_packed;
    
    // Pack characters into 64-bit words for easier comparison
    assign planet1_packed = {planet1_char7, planet1_char6, planet1_char5, planet1_char4,
                             planet1_char3, planet1_char2, planet1_char1, planet1_char0};
    assign planet2_packed = {planet2_char7, planet2_char6, planet2_char5, planet2_char4,
                             planet2_char3, planet2_char2, planet2_char1, planet2_char0};
    
    // Decode logic for planet1
    always @(*) begin
        valid1 = 1'b0;
        index1 = 3'd0;
        
        case (planet1_packed)
            64'h4d657263757279: begin // "Mercury"
                valid1 = 1'b1;
                index1 = MERCURY;
            end
            64'h56656e75732020: begin // "Venus  "
                valid1 = 1'b1;
                index1 = VENUS;
            end
            64'h45617274682020: begin // "Earth  "
                valid1 = 1'b1;
                index1 = EARTH;
            end
            64'h4d617273202020: begin // "Mars   "
                valid1 = 1'b1;
                index1 = MARS;
            end
            64'h4a757069746572: begin // "Jupiter"
                valid1 = 1'b1;
                index1 = JUPITER;
            end
            64'h53617475726e20: begin // "Saturn "
                valid1 = 1'b1;
                index1 = SATURN;
            end
            64'h5572616e757320: begin // "Uranus "
                valid1 = 1'b1;
                index1 = URANUS;
            end
            64'h4e657074756e65: begin // "Neptune"
                valid1 = 1'b1;
                index1 = NEPTUNE;
            end
            default: begin
                valid1 = 1'b0;
                index1 = 3'd0;
            end
        endcase
    end
    
    // Decode logic for planet2
    always @(*) begin
        valid2 = 1'b0;
        index2 = 3'd0;
        
        case (planet2_packed)
            64'h4d657263757279: begin // "Mercury"
                valid2 = 1'b1;
                index2 = MERCURY;
            end
            64'h56656e75732020: begin // "Venus  "
                valid2 = 1'b1;
                index2 = VENUS;
            end
            64'h45617274682020: begin // "Earth  "
                valid2 = 1'b1;
                index2 = EARTH;
            end
            64'h4d617273202020: begin // "Mars   "
                valid2 = 1'b1;
                index2 = MARS;
            end
            64'h4a757069746572: begin // "Jupiter"
                valid2 = 1'b1;
                index2 = JUPITER;
            end
            64'h53617475726e20: begin // "Saturn "
                valid2 = 1'b1;
                index2 = SATURN;
            end
            64'h5572616e757320: begin // "Uranus "
                valid2 = 1'b1;
                index2 = URANUS;
            end
            64'h4e657074756e65: begin // "Neptune"
                valid2 = 1'b1;
                index2 = NEPTUNE;
            end
            default: begin
                valid2 = 1'b0;
                index2 = 3'd0;
            end
        endcase
    end
    
    // Generate output mask
    always @(*) begin
        mask = 8'b00000000;
        
        // Check if both inputs are valid and different
        if (valid1 && valid2 && (index1 != index2)) begin
            // Determine min and max indices
            if (index1 < index2) begin
                min_index = index1;
                max_index = index2;
            end else begin
                min_index = index2;
                max_index = index1;
            end
            
            // Set bits for planets strictly between min and max
            // Bit 0 = Mercury (MSB for bit positions 0-7)
            for (i = 0; i < 8; i = i + 1) begin
                if ((i > min_index) && (i < max_index)) begin
                    mask[i] = 1'b1;
                end
            end
        end
        
        result = mask;
    end

endmodule