module min_extensions_finder (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [15:0] rect_a,
    input wire [15:0] rect_b,
    input wire [15:0] field_h,
    input wire [15:0] field_w,
    input wire [2:0] num_extensions,
    input wire [15:0] ext_0,
    input wire [15:0] ext_1,
    input wire [15:0] ext_2,
    input wire [15:0] ext_3,
    input wire [15:0] ext_4,
    input wire [15:0] ext_5,
    input wire [15:0] ext_6,
    input wire [15:0] ext_7,
    output reg [7:0] min_count,
    output reg done
);

    // State definitions
    localparam IDLE = 3'b000;
    localparam CHECKInitial = 3'b001;
    localparam GEN_COMBOS = 3'b010;
    localparam CHECK_COMBOS = 3'b011;
    localparam FINISHED = 3'b100;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Helper variables
    reg [2:0] k; // Number of extensions to use (1 to num_extensions)
    reg [2:0] combo_idx; // Index for iterating through combinations
    reg [15:0] current_h;
    reg [15:0] current_w;
    reg valid_found;
    
    // Combinational check logic
    // Check if field (h, w) can fit rectangle (a, b)
    wire fits_h_a;
    wire fits_w_b;
    wire fits_h_b;
    wire fits_w_a;
    wire is_valid;
    
    assign fits_h_a = (current_h >= rect_a);
    assign fits_w_b = (current_w >= rect_b);
    assign fits_h_b = (current_h >= rect_b);
    assign fits_w_a = (current_w >= rect_a);
    assign is_valid = (fits_h_a && fits_w_b) || (fits_h_b && fits_w_a);
    
    // Multiplier input selection logic
    reg [15:0] multiplier;
    always @(*) begin
        case(combo_idx)
            3'd0: multiplier = ext_0;
            3'd1: multiplier = ext_1;
            3'd2: multiplier = ext_2;
            3'd3: multiplier = ext_3;
            3'd4: multiplier = ext_4;
            3'd5: multiplier = ext_5;
            3'd6: multiplier = ext_6;
            3'd7: multiplier = ext_7;
            default: multiplier = 16'd1;
        endcase
    end

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            min_count <= 8'd255; // Initialize to max (invalid)
            done <= 1'b0;
            k <= 3'd0;
            combo_idx <= 3'd0;
            current_h <= 16'd0;
            current_w <= 16'd0;
            valid_found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initial check with 0 extensions
                        current_h <= field_h;
                        current_w <= field_w;
                        min_count <= 8'd255;
                        valid_found <= 1'b0;
                        k <= 3'd1; // Start checking from 1 extension
                        combo_idx <= 3'd0;
                        next_state <= CHECKInitial;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                CHECKInitial: begin
                    if (is_valid) begin
                        min_count <= 8'd0;
                        done <= 1'b1;
                        next_state <= FINISHED;
                    end else begin
                        next_state <= GEN_COMBOS;
                    end
                end

                GEN_COMBOS: begin
                    // Reset for this k
                    combo_idx <= 3'd0;
                    current_h <= field_h;
                    current_w <= field_w;
                    // We only iterate through the first k extensions for simplicity
                    // This covers the "use any k extensions" logic if sorted
                    next_state <= CHECK_COMBOS;
                end

                CHECK_COMBOS: begin
                    // Apply current multiplier
                    if (combo_idx < k) begin
                        // Split extensions: assign to H or W based on simple heuristic
                        // Even idx -> H, Odd idx -> W (alternate)
                        if (combo_idx[0] == 1'b0) begin
                            current_h <= current_h * multiplier;
                        end else begin
                            current_w <= current_w * multiplier;
                        end
                        combo_idx <= combo_idx + 3'd1;
                        next_state <= CHECK_COMBOS;
                    end else begin
                        // Done applying k extensions, check validity
                        if (is_valid) begin
                            if (min_count > k) begin
                                min_count <= k;
                            end
                            valid_found <= 1'b1;
                        end
                        
                        // Prepare for next k
                        if (k < num_extensions && k < 4'd6) begin // Limit iterations for timing
                            k <= k + 3'd1;
                            next_state <= GEN_COMBOS;
                        end else begin
                            next_state <= FINISHED;
                        end
                    end
                end

                FINISHED: begin
                    if (min_count == 8'd255) begin
                        min_count <= 8'd255; // Indicate -1 (impossible)
                    end
                    done <= 1'b1;
                    if (!start) next_state <= IDLE;
                    else next_state <= FINISHED;
                end
            endcase
        end
    end

endmodule