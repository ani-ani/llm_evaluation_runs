module find_positions (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,   // Actual size of a (≤16)
    input wire [3:0] m,   // Actual size of b (≤8)
    input wire [3:0] p,   // Step size (≤8)
    // Input array a (16 elements, 4-bit each)
    input wire [3:0] a0, a1, a2, a3, a4, a5, a6, a7,
    input wire [3:0] a8, a9, a10, a11, a12, a13, a14, a15,
    // Input array b (8 elements, 4-bit each)
    input wire [3:0] b0, b1, b2, b3, b4, b5, b6, b7,
    output reg done,
    output reg [3:0] count,    // Number of valid positions
    // Output positions (max 16, 5-bit each)
    output reg [4:0] pos0, pos1, pos2, pos3, pos4, pos5, pos6, pos7,
    output reg [4:0] pos8, pos9, pos10, pos11, pos12, pos13, pos14, pos15
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] PREPARE_B = 3'd1;
localparam [2:0] CHECK_Q = 3'd2;
localparam [2:0] INIT_WINDOW = 3'd3;
localparam [2:0] CHECK_WINDOW = 3'd4;
localparam [2:0] SLIDE = 3'd5;
localparam [2:0] SORT = 3'd6;
localparam [2:0] FINISH = 3'd7;

// Registers
reg [2:0] state;
reg [3:0] q;              // Current starting position
reg [3:0] j;              // Window offset counter
reg [3:0] elem_count;     // Elements in current sequence
reg [3:0] pos_count;      // Count of found positions
reg signed [4:0] temp_pos [0:15]; // Temporary position storage

// Frequency tables (values 0-15)
reg [3:0] freq_b [0:15];   // Frequency of b values
reg [3:0] freq_win [0:15]; // Frequency in current window

// Helper signals
reg [3:0] a_vals [0:15];   // Input a array
reg [3:0] b_vals [0:15];   // Input b array (padded to 16)
reg freq_match;

// Map inputs to arrays
always @(*) begin
    a_vals[0] = a0;  a_vals[1] = a1;  a_vals[2] = a2;  a_vals[3] = a3;
    a_vals[4] = a4;  a_vals[5] = a5;  a_vals[6] = a6;  a_vals[7] = a7;
    a_vals[8] = a8;  a_vals[9] = a9;  a_vals[10] = a10; a_vals[11] = a11;
    a_vals[12] = a12; a_vals[13] = a13; a_vals[14] = a14; a_vals[15] = a15;
    
    b_vals[0] = b0;  b_vals[1] = b1;  b_vals[2] = b2;  b_vals[3] = b3;
    b_vals[4] = b4;  b_vals[5] = b5;  b_vals[6] = b6;  b_vals[7] = b7;
    // Pad remaining to 0
    for (integer i = 8; i < 16; i = i + 1) b_vals[i] = 0;
end

// Frequency comparison
always @(*) begin
    freq_match = 1;
    for (integer i = 0; i < 16; i = i + 1) begin
        if (freq_b[i] != freq_win[i]) freq_match = 0;
    end
end

// Next state logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        count <= 4'd0;
        pos0 <= 5'd0; pos1 <= 5'd0; pos2 <= 5'd0; pos3 <= 5'd0;
        pos4 <= 5'd0; pos5 <= 5'd0; pos6 <= 5'd0; pos7 <= 5'd0;
        pos8 <= 5'd0; pos9 <= 5'd0; pos10 <= 5'd0; pos11 <= 5'd0;
        pos12 <= 5'd0; pos13 <= 5'd0; pos14 <= 5'd0; pos15 <= 5'd0;
        q <= 4'd0;
        j <= 4'd0;
        pos_count <= 4'd0;
        // Reset frequency tables
        for (integer i = 0; i < 16; i = i + 1) begin
            freq_b[i] <= 4'd0;
            freq_win[i] <= 4'd0;
            temp_pos[i] <= 5'd0;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PREPARE_B;
                    q <= 4'd0;
                    j <= 4'd0;
                    pos_count <= 4'd0;
                    // Reset frequency tables
                    for (integer i = 0; i < 16; i = i + 1) begin
                        freq_b[i] <= 4'd0;
                        freq_win[i] <= 4'd0;
                    end
                end
            end
            
            PREPARE_B: begin
                // Build frequency table for b (first m elements)
                if (j < m) begin
                    if (b_vals[j] < 16)  // Safety check
                        freq_b[b_vals[j]] <= freq_b[b_vals[j]] + 1'b1;
                    j <= j + 1'b1;
                end else begin
                    j <= 4'd0;
                    state <= CHECK_Q;
                end
            end
            
            CHECK_Q: begin
                if (q < p) begin
                    // Check if valid sequence exists
                    if (n > q) begin
                        elem_count <= (n - q - 1'b1) / p + 1'b1;  // Number of elements
                        state <= INIT_WINDOW;
                        j <= 4'd0;
                        // Reset freq_win
                        for (integer i = 0; i < 16; i = i + 1) freq_win[i] <= 4'd0;
                    end else begin
                        q <= q + 1'b1;
                    end
                end else begin
                    state <= SORT;
                    j <= 4'd0; // Use j as counter for sort
                end
            end
            
            INIT_WINDOW: begin
                if (j < m) begin
                    // Get element at position q + j*p
                    if (q + j*p < 16 && a_vals[q + j*p] < 16)
                        freq_win[a_vals[q + j*p]] <= freq_win[a_vals[q + j*p]] + 1'b1;
                    j <= j + 1'b1;
                end else begin
                    j <= 4'd0;
                    state <= CHECK_WINDOW;
                end
            end
            
            CHECK_WINDOW: begin
                if (elem_count >= m && freq_match) begin
                    // Record position (1-indexed)
                    if (pos_count < 16) begin
                        temp_pos[pos_count] <= q + 1'b1;
                        pos_count <= pos_count + 1'b1;
                    end
                end
                
                // Check if we can slide
                if (elem_count > m) begin
                    state <= SLIDE;
                end else begin
                    q <= q + 1'b1;
                    state <= CHECK_Q;
                end
            end
            
            SLIDE: begin
                // Remove leftmost element (at j in sequence)
                if (q + j*p < 16 && a_vals[q + j*p] < 16)
                    freq_win[a_vals[q + j*p]] <= freq_win[a_vals[q + j*p]] - 1'b1;
                
                // Add new element (at j+m in sequence)
                if (q + (j+m)*p < 16 && a_vals[q + (j+m)*p] < 16)
                    freq_win[a_vals[q + (j+m)*p]] <= freq_win[a_vals[q + (j+m)*p]] + 1'b1;
                
                j <= j + 1'b1;
                elem_count <= elem_count - 1'b1; // One less window available
                state <= CHECK_WINDOW;
            end
            
            SORT: begin
                // Bubble sort on temp_pos (only first pos_count elements)
                if (j < pos_count - 1'b1) begin
                    if (temp_pos[j] > temp_pos[j+1]) begin
                        // Swap
                        temp_pos[j] <= temp_pos[j+1];
                        temp_pos[j+1] <= temp_pos[j];
                    end
                    j <= j + 1'b1;
                end else begin
                    j <= 4'd0;
                    state <= FINISH;
                end
            end
            
            FINISH: begin
                // Assign outputs
                count <= pos_count;
                pos0 <= temp_pos[0]; pos1 <= temp_pos[1]; pos2 <= temp_pos[2]; pos3 <= temp_pos[3];
                pos4 <= temp_pos[4]; pos5 <= temp_pos[5]; pos6 <= temp_pos[6]; pos7 <= temp_pos[7];
                pos8 <= temp_pos[8]; pos9 <= temp_pos[9]; pos10 <= temp_pos[10]; pos11 <= temp_pos[11];
                pos12 <= temp_pos[12]; pos13 <= temp_pos[13]; pos14 <= temp_pos[14]; pos15 <= temp_pos[15];
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule