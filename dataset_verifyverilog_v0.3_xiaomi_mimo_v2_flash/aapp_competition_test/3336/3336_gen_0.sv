module max_excursion (
    input clk,              // Clock signal
    input rst_n,            // Active-low reset
    input start,            // Start pulse (1 cycle)
    input [7:0] valid,      // Valid mask for pupils (1=valid)
    input [31:0] arr_0,     // Pupil 0 data: {sport[7:0], music[7:0], height[11:0], sex[0], unused[2:0]}
    input [31:0] arr_1,     // Pupil 1 data
    input [31:0] arr_2,     // Pupil 2 data
    input [31:0] arr_3,     // Pupil 3 data
    input [31:0] arr_4,     // Pupil 4 data
    input [31:0] arr_5,     // Pupil 5 data
    input [31:0] arr_6,     // Pupil 6 data
    input [31:0] arr_7,     // Pupil 7 data
    output reg [7:0] max_size, // Maximum eligible pupils
    output reg done           // Computation done (1 cycle)
);

// State definitions
localparam [2:0] S_IDLE = 3'd0;
localparam [2:0] S_DECODE = 3'd1;
localparam [2:0] S_ENUM_START = 3'd2;
localparam [2:0] S_ENUM_CHECK = 3'd3;
localparam [2:0] S_ENUM_POPCOUNT = 3'd4;

// Internal registers
reg [2:0] state;
reg [7:0] mask_reg;        // Current subset mask
reg [7:0] max_size_reg;    // Internal max size
reg [2:0] i_idx;           // Outer pair index
reg [3:0] j_idx;           // Inner pair index (can go to 8)
reg checking_valid;        // Flag for current mask validity

// Registered attributes for each pupil
reg [11:0] height_0, height_1, height_2, height_3, height_4, height_5, height_6, height_7;
reg sex_0, sex_1, sex_2, sex_3, sex_4, sex_5, sex_6, sex_7;
reg [7:0] music_0, music_1, music_2, music_3, music_4, music_5, music_6, music_7;
reg [7:0] sport_0, sport_1, sport_2, sport_3, sport_4, sport_5, sport_6, sport_7;

// Combinational signals for compatibility check
reg [11:0] h_i, h_j;
reg sex_i, sex_j;
reg [7:0] music_i, music_j, sport_i, sport_j;
wire comp_ij;
wire cond1, cond2, cond3, cond4;

// Popcount computation (8-bit)
wire [7:0] popcount_result;
assign popcount_result = mask_reg[0] + mask_reg[1] + mask_reg[2] + mask_reg[3] + 
                        mask_reg[4] + mask_reg[5] + mask_reg[6] + mask_reg[7];

// Compatibility computation
always @* begin
    // Select attributes based on i_idx and j_idx
    case(i_idx)
        3'd0: begin h_i = height_0; sex_i = sex_0; music_i = music_0; sport_i = sport_0; end
        3'd1: begin h_i = height_1; sex_i = sex_1; music_i = music_1; sport_i = sport_1; end
        3'd2: begin h_i = height_2; sex_i = sex_2; music_i = music_2; sport_i = sport_2; end
        3'd3: begin h_i = height_3; sex_i = sex_3; music_i = music_3; sport_i = sport_3; end
        3'd4: begin h_i = height_4; sex_i = sex_4; music_i = music_4; sport_i = sport_4; end
        3'd5: begin h_i = height_5; sex_i = sex_5; music_i = music_5; sport_i = sport_5; end
        3'd6: begin h_i = height_6; sex_i = sex_6; music_i = music_6; sport_i = sport_6; end
        3'd7: begin h_i = height_7; sex_i = sex_7; music_i = music_7; sport_i = sport_7; end
        default: begin h_i = 12'd0; sex_i = 1'd0; music_i = 8'd0; sport_i = 8'd0; end
    endcase
    case(j_idx)
        4'd0: begin h_j = height_0; sex_j = sex_0; music_j = music_0; sport_j = sport_0; end
        4'd1: begin h_j = height_1; sex_j = sex_1; music_j = music_1; sport_j = sport_1; end
        4'd2: begin h_j = height_2; sex_j = sex_2; music_j = music_2; sport_j = sport_2; end
        4'd3: begin h_j = height_3; sex_j = sex_3; music_j = music_3; sport_j = sport_3; end
        4'd4: begin h_j = height_4; sex_j = sex_4; music_j = music_4; sport_j = sport_4; end
        4'd5: begin h_j = height_5; sex_j = sex_5; music_j = music_5; sport_j = sport_5; end
        4'd6: begin h_j = height_6; sex_j = sex_6; music_j = music_6; sport_j = sport_6; end
        4'd7: begin h_j = height_7; sex_j = sex_7; music_j = music_7; sport_j = sport_7; end
        default: begin h_j = 12'd0; sex_j = 1'd0; music_j = 8'd0; sport_j = 8'd0; end
    endcase
    // Conditions
    cond1 = (h_i > h_j + 12'd40) || (h_j > h_i + 12'd40); // Height diff > 40
    cond2 = (sex_i == sex_j);                               // Same sex
    cond3 = (music_i != music_j);                           // Different music
    cond4 = (sport_i == sport_j);                           // Same sport
    comp_ij = cond1 || cond2 || cond3 || cond4;
end

// Main state machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= S_IDLE;
        done <= 1'b0;
        max_size <= 8'd0;
        mask_reg <= 8'd0;
        max_size_reg <= 8'd0;
        checking_valid <= 1'b0;
        i_idx <= 3'd0;
        j_idx <= 4'd0;
        // Reset attributes to zero
        height_0 <= 12'd0; height_1 <= 12'd0; height_2 <= 12'd0; height_3 <= 12'd0;
        height_4 <= 12'd0; height_5 <= 12'd0; height_6 <= 12'd0; height_7 <= 12'd0;
        sex_0 <= 1'b0; sex_1 <= 1'b0; sex_2 <= 1'b0; sex_3 <= 1'b0;
        sex_4 <= 1'b0; sex_5 <= 1'b0; sex_6 <= 1'b0; sex_7 <= 1'b0;
        music_0 <= 8'd0; music_1 <= 8'd0; music_2 <= 8'd0; music_3 <= 8'd0;
        music_4 <= 8'd0; music_5 <= 8'd0; music_6 <= 8'd0; music_7 <= 8'd0;
        sport_0 <= 8'd0; sport_1 <= 8'd0; sport_2 <= 8'd0; sport_3 <= 8'd0;
        sport_4 <= 8'd0; sport_5 <= 8'd0; sport_6 <= 8'd0; sport_7 <= 8'd0;
    end else begin
        case (state)
            S_IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= S_DECODE;
                end
            end

            S_DECODE: begin
                // Decode and register pupil data
                // arr_X[15:4] = height, arr_X[3] = sex, arr_X[23:16] = music, arr_X[31:24] = sport
                height_0 <= arr_0[15:4]; sex_0 <= arr_0[3]; music_0 <= arr_0[23:16]; sport_0 <= arr_0[31:24];
                height_1 <= arr_1[15:4]; sex_1 <= arr_1[3]; music_1 <= arr_1[23:16]; sport_1 <= arr_1[31:24];
                height_2 <= arr_2[15:4]; sex_2 <= arr_2[3]; music_2 <= arr_2[23:16]; sport_2 <= arr_2[31:24];
                height_3 <= arr_3[15:4]; sex_3 <= arr_3[3]; music_3 <= arr_3[23:16]; sport_3 <= arr_3[31:24];
                height_4 <= arr_4[15:4]; sex_4 <= arr_4[3]; music_4 <= arr_4[23:16]; sport_4 <= arr_4[31:24];
                height_5 <= arr_5[15:4]; sex_5 <= arr_5[3]; music_5 <= arr_5[23:16]; sport_5 <= arr_5[31:24];
                height_6 <= arr_6[15:4]; sex_6 <= arr_6[3]; music_6 <= arr_6[23:16]; sport_6 <= arr_6[31:24];
                height_7 <= arr_7[15:4]; sex_7 <= arr_7[3]; music_7 <= arr_7[23:16]; sport_7 <= arr_7[31:24];
                // Initialize enumeration
                mask_reg <= 8'd0;
                max_size_reg <= 8'd0;
                state <= S_ENUM_START;
            end

            S_ENUM_START: begin
                if (mask_reg > 8'hFF) begin
                    // Finished all masks
                    max_size <= max_size_reg;
                    done <= 1'b1;
                    state <= S_IDLE;
                end else begin
                    // Check if mask is subset of valid set
                    if ((mask_reg & ~valid) == 8'd0) begin
                        // Initialize pair checking
                        i_idx <= 3'd0;
                        j_idx <= 4'd1;
                        checking_valid <= 1'b1;
                        state <= S_ENUM_CHECK;
                    end else begin
                        // Skip invalid mask
                        mask_reg <= mask_reg + 8'd1;
                        state <= S_ENUM_START;
                    end
                end
            end

            S_ENUM_CHECK: begin
                if (i_idx >= 3'd7 && j_idx >= 4'd8) begin
                    // Finished all pairs for this mask
                    if (checking_valid) begin
                        state <= S_ENUM_POPCOUNT;
                    end else begin
                        mask_reg <= mask_reg + 8'd1;
                        state <= S_ENUM_START;
                    end
                end else if (j_idx >= 4'd8) begin
                    // Move to next i
                    i_idx <= i_idx + 3'd1;
                    j_idx <= i_idx + 3'd2;
                end else begin
                    // Check if both pupils are in the mask
                    if (mask_reg[i_idx] && mask_reg[j_idx]) begin
                        // Compute compatibility
                        if (!comp_ij) begin
                            checking_valid <= 1'b0;
                        end
                    end
                    j_idx <= j_idx + 4'd1;
                end
            end

            S_ENUM_POPCOUNT: begin
                // Update max size if current mask is larger
                if (popcount_result > max_size_reg) begin
                    max_size_reg <= popcount_result;
                end
                mask_reg <= mask_reg + 8'd1;
                state <= S_ENUM_START;
            end

            default: state <= S_IDLE;
        endcase
    end
end

endmodule